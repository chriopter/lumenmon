#!/usr/bin/env python3
"""
SMTP receiver that accepts incoming mail and stores in SQLite.
Matches recipient email to agent IDs for per-machine messages.
Unknown recipients go to catch-all inbox.
"""

import asyncio
import sqlite3
import email
import os
import sys
import signal
from email.policy import default as default_policy
from aiosmtpd.controller import Controller

DB_PATH = os.environ.get('LUMENMON_DB', '/data/metrics.db')
SMTP_PORT = int(os.environ.get('SMTP_PORT', 25))


def init_messages_table():
    """Create messages table if not exists."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute('''
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            agent_id TEXT,
            mail_from TEXT,
            mail_to TEXT,
            subject TEXT,
            body TEXT,
            raw_content TEXT,
            received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            read INTEGER DEFAULT 0
        )
    ''')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_messages_agent ON messages(agent_id)')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_messages_read ON messages(read)')
    conn.commit()
    conn.close()
    print(f"[smtp] Messages table initialized", flush=True)


MQTT_PASSWD_FILE = '/data/mqtt/passwd'


def get_agent_ids():
    """Get list of valid agent IDs from database and MQTT password file."""
    agent_ids = set()

    # 1. Get from database tables
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.execute("""
            SELECT name FROM sqlite_master
            WHERE type='table' AND name LIKE 'id_%'
        """)
        tables = cursor.fetchall()
        conn.close()

        for (table_name,) in tables:
            # Table names are like id_abc123_metric_name
            parts = table_name.split('_')
            if len(parts) >= 2:
                agent_id = f"{parts[0]}_{parts[1]}"
                agent_ids.add(agent_id)
    except Exception as e:
        print(f"[smtp] Error getting agent IDs from DB: {e}", flush=True)

    # 2. Also get from MQTT password file (agents may exist before sending data)
    try:
        if os.path.exists(MQTT_PASSWD_FILE):
            with open(MQTT_PASSWD_FILE, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and ':' in line:
                        username = line.split(':')[0]
                        if username.startswith('id_'):
                            agent_ids.add(username)
    except Exception as e:
        print(f"[smtp] Error getting agent IDs from passwd: {e}", flush=True)

    return agent_ids


def extract_agent_from_recipient(recipient):
    """
    Extract agent ID from recipient email address.
    Format: <agent_id>@<domain> or <random_token>@<domain>
    Returns agent_id if matched, None for unknown.
    """
    if not recipient:
        return None

    # Get local part (before @)
    local_part = recipient.split('@')[0].lower().strip()

    # Check if it matches an agent ID directly (id_xxxxxxxx)
    agent_ids = get_agent_ids()

    if local_part in agent_ids:
        return local_part

    # Also check without id_ prefix
    for agent_id in agent_ids:
        if agent_id.replace('id_', '') == local_part:
            return agent_id

    # TODO: Could add lookup table for custom email tokens → agent mappings

    return None


def store_message(agent_id, mail_from, mail_to, subject, body, raw_content):
    """Store message in SQLite."""
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.execute('''
            INSERT INTO messages (agent_id, mail_from, mail_to, subject, body, raw_content)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (agent_id, mail_from, mail_to, subject, body, raw_content))
        conn.commit()
        conn.close()

        dest = agent_id if agent_id else 'unknown'
        print(f"[smtp] Stored message for {dest}: {subject[:50]}", flush=True)
        return True
    except Exception as e:
        print(f"[smtp] Error storing message: {e}", flush=True)
        return False


class LumenmonSMTPHandler:
    """Handler for incoming SMTP messages."""

    async def handle_RCPT(self, server, session, envelope, address, rcpt_options):
        """Accept if this or any previous recipient matches a known agent."""
        envelope.rcpt_tos.append(address)

        # Check if ANY recipient so far matches a known agent
        for rcpt in envelope.rcpt_tos:
            if extract_agent_from_recipient(rcpt):
                return '250 OK'

        # No match yet - accept anyway, final check happens in handle_DATA
        # This allows multi-recipient emails where agent ID comes later
        return '250 OK'

    async def handle_DATA(self, server, session, envelope):
        """Process incoming message - only store if a recipient matches known agent."""
        # First verify at least one recipient is a known agent
        agent_id = None
        for rcpt in envelope.rcpt_tos:
            agent_id = extract_agent_from_recipient(rcpt)
            if agent_id:
                break

        if not agent_id:
            # No valid agent recipient - reject to prevent spam
            print(f"[smtp] Rejected: no valid agent in recipients {envelope.rcpt_tos}", flush=True)
            return '550 No valid recipient'

        try:
            mail_from = envelope.mail_from
            mail_to = ', '.join(envelope.rcpt_tos) if envelope.rcpt_tos else ''
            raw_content = envelope.content.decode('utf-8', errors='replace')

            # Parse email
            msg = email.message_from_string(raw_content, policy=default_policy)
            subject = msg.get('Subject', '(no subject)')

            # Extract body
            body = ''
            if msg.is_multipart():
                for part in msg.walk():
                    if part.get_content_type() == 'text/plain':
                        payload = part.get_payload(decode=True)
                        if payload:
                            body = payload.decode('utf-8', errors='replace')
                            break
            else:
                payload = msg.get_payload(decode=True)
                if payload:
                    body = payload.decode('utf-8', errors='replace')

            # Store message
            store_message(agent_id, mail_from, mail_to, subject, body, raw_content)

            print(f"[smtp] Received: from={mail_from} to={mail_to} subject={subject[:30]}...", flush=True)
            return '250 Message accepted'

        except Exception as e:
            print(f"[smtp] Error processing message: {e}", flush=True)
            return '550 Error processing message'


async def run_smtp_server():
    """Run the SMTP server."""
    init_messages_table()

    handler = LumenmonSMTPHandler()
    controller = Controller(
        handler,
        hostname='0.0.0.0',
        port=SMTP_PORT,
        ready_timeout=10
    )

    controller.start()
    print(f"[smtp] SMTP receiver started on port {SMTP_PORT}", flush=True)

    # Keep running until interrupted
    try:
        while True:
            await asyncio.sleep(3600)
    except asyncio.CancelledError:
        pass
    finally:
        controller.stop()
        print("[smtp] SMTP receiver stopped", flush=True)


def main():
    """Main entry point."""
    print("[smtp] Starting SMTP receiver...", flush=True)

    # Handle signals
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    def shutdown(sig, frame):
        print(f"[smtp] Received signal {sig}, shutting down...", flush=True)
        loop.stop()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    try:
        loop.run_until_complete(run_smtp_server())
    except KeyboardInterrupt:
        pass
    finally:
        loop.close()


if __name__ == '__main__':
    main()
