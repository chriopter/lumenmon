#!/usr/bin/env python3
"""
Messages blueprint - imported by unified_server.py.
Provides /api/messages endpoints for SMTP-received mail.
NOTE: Uses SQLite directly (not RAM) since messages are infrequent.
"""

from flask import Blueprint, jsonify, request
from db import get_db_connection
import secrets
import string
from datetime import datetime, timezone

messages_bp = Blueprint('messages', __name__)

DEFAULT_STALENESS_HOURS = 336  # 14 days
MAX_STALENESS_HOURS = 8760


def parse_limit_param(raw_value, default_value, max_value):
    """Parse limit query parameter with bounds checking."""
    if raw_value is None or raw_value == '':
        return default_value
    value = int(raw_value)
    if value < 1:
        raise ValueError('limit must be >= 1')
    return min(value, max_value)


def parse_hours_param(raw_value, default_value, max_value):
    """Parse staleness threshold hours query parameter."""
    if raw_value is None or raw_value == '':
        return default_value
    value = int(raw_value)
    if value < 1:
        raise ValueError('hours must be >= 1')
    return min(value, max_value)


def parse_sqlite_timestamp(ts_value):
    """Parse SQLite timestamp strings into UTC-aware datetimes."""
    if not ts_value:
        return None
    try:
        if ts_value.endswith('Z'):
            return datetime.fromisoformat(ts_value.replace('Z', '+00:00')).astimezone(timezone.utc)
        parsed = datetime.fromisoformat(ts_value)
        if parsed.tzinfo is None:
            return parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    except Exception:
        return None




def generate_mail_token(length=16):
    """Generate a random mail token for agent email addresses."""
    alphabet = string.ascii_lowercase + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))


@messages_bp.route('/api/messages', methods=['GET'])
def list_all_messages():
    """List all messages, optionally filtered by agent_id or read status."""
    conn = None
    try:
        agent_id = request.args.get('agent_id')
        unread_only = request.args.get('unread', '').lower() == 'true'
        limit = parse_limit_param(request.args.get('limit'), 100, 500)

        conn = get_db_connection()
        query = 'SELECT id, agent_id, mail_from, mail_to, subject, received_at, read FROM messages'
        conditions = []
        params = []

        if agent_id == 'unknown':
            conditions.append('agent_id IS NULL')
        elif agent_id:
            conditions.append('agent_id = ?')
            params.append(agent_id)

        if unread_only:
            conditions.append('read = 0')

        if conditions:
            query += ' WHERE ' + ' AND '.join(conditions)

        query += ' ORDER BY received_at DESC LIMIT ?'
        params.append(limit)

        cursor = conn.execute(query, params)
        messages = []
        for row in cursor.fetchall():
            messages.append({
                'id': row[0],
                'agent_id': row[1],
                'mail_from': row[2],
                'mail_to': row[3],
                'subject': row[4],
                'received_at': row[5],
                'read': bool(row[6])
            })

        return jsonify({'messages': messages})
    except ValueError:
        return jsonify({'error': 'Invalid limit parameter'}), 400
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass


@messages_bp.route('/api/messages/unread-counts', methods=['GET'])
def unread_counts():
    """Get unread message counts per agent (for badges)."""
    conn = get_db_connection()
    try:
        cursor = conn.execute('''
            SELECT
                COALESCE(agent_id, 'unknown') as agent,
                COUNT(*) as count
            FROM messages
            WHERE read = 0
            GROUP BY agent_id
        ''')

        counts = {}
        for row in cursor.fetchall():
            counts[row[0]] = row[1]

        return jsonify({'counts': counts})
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        conn.close()


@messages_bp.route('/api/messages/staleness', methods=['GET'])
def messages_staleness():
    """Server-side mail staleness report using messages.received_at."""
    conn = get_db_connection()
    try:
        threshold_hours = parse_hours_param(
            request.args.get('hours'),
            DEFAULT_STALENESS_HOURS,
            MAX_STALENESS_HOURS,
        )
        now = datetime.now(timezone.utc)

        cursor = conn.execute('''
            SELECT COALESCE(agent_id, 'unknown') as agent_id, MAX(received_at) as last_received
            FROM messages
            GROUP BY COALESCE(agent_id, 'unknown')
        ''')

        per_agent = []
        stale_agents = 0
        for row in cursor.fetchall():
            agent_id = row[0]
            last_received = row[1]
            parsed = parse_sqlite_timestamp(last_received)
            if parsed is None:
                age_hours = None
                is_stale = True
            else:
                age_hours = int((now - parsed).total_seconds() // 3600)
                is_stale = age_hours > threshold_hours

            if is_stale:
                stale_agents += 1

            per_agent.append({
                'agent_id': agent_id,
                'last_received': last_received,
                'age_hours': age_hours,
                'is_stale': is_stale,
            })

        global_last = max((a['last_received'] for a in per_agent if a['last_received']), default=None)
        global_parsed = parse_sqlite_timestamp(global_last) if global_last else None
        global_age_hours = int((now - global_parsed).total_seconds() // 3600) if global_parsed else None

        return jsonify({
            'threshold_hours': threshold_hours,
            'global': {
                'last_received': global_last,
                'age_hours': global_age_hours,
                'is_stale': global_age_hours is None or global_age_hours > threshold_hours,
            },
            'summary': {
                'agents_with_mail': len(per_agent),
                'stale_agents': stale_agents,
            },
            'per_agent': per_agent,
        })
    except ValueError:
        return jsonify({'error': 'Invalid hours parameter'}), 400
    except Exception:
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        conn.close()




@messages_bp.route('/api/messages/<int:message_id>', methods=['GET'])
def get_message(message_id):
    """Get a single message by ID (marks as read)."""
    conn = get_db_connection()
    try:
        cursor = conn.execute('''
            SELECT id, agent_id, mail_from, mail_to, subject, body, received_at, read
            FROM messages WHERE id = ?
        ''', (message_id,))
        row = cursor.fetchone()

        if not row:
            return jsonify({'error': 'Message not found'}), 404

        # Mark as read
        conn.execute('UPDATE messages SET read = 1 WHERE id = ?', (message_id,))
        conn.commit()

        return jsonify({
            'id': row[0],
            'agent_id': row[1],
            'mail_from': row[2],
            'mail_to': row[3],
            'subject': row[4],
            'body': row[5],
            'received_at': row[6],
            'read': True
        })
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        conn.close()


@messages_bp.route('/api/messages/<int:message_id>/read', methods=['POST'])
def mark_read(message_id):
    """Mark a message as read."""
    conn = get_db_connection()
    try:
        conn.execute('UPDATE messages SET read = 1 WHERE id = ?', (message_id,))
        conn.commit()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        conn.close()


@messages_bp.route('/api/messages/<int:message_id>', methods=['DELETE'])
def delete_message(message_id):
    """Delete a message."""
    conn = get_db_connection()
    try:
        conn.execute('DELETE FROM messages WHERE id = ?', (message_id,))
        conn.commit()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        conn.close()


@messages_bp.route('/api/agents/<agent_id>/messages', methods=['GET'])
def agent_messages(agent_id):
    """Get messages for a specific agent."""
    conn = None
    try:
        limit = parse_limit_param(request.args.get('limit'), 50, 500)

        conn = get_db_connection()
        if agent_id == 'unknown':
            cursor = conn.execute('''
                SELECT id, agent_id, mail_from, mail_to, subject, received_at, read
                FROM messages WHERE agent_id IS NULL
                ORDER BY received_at DESC LIMIT ?
            ''', (limit,))
        else:
            cursor = conn.execute('''
                SELECT id, agent_id, mail_from, mail_to, subject, received_at, read
                FROM messages WHERE agent_id = ?
                ORDER BY received_at DESC LIMIT ?
            ''', (agent_id, limit))

        messages = []
        for row in cursor.fetchall():
            messages.append({
                'id': row[0],
                'agent_id': row[1],
                'mail_from': row[2],
                'mail_to': row[3],
                'subject': row[4],
                'received_at': row[5],
                'read': bool(row[6])
            })

        return jsonify({'messages': messages})
    except ValueError:
        return jsonify({'error': 'Invalid limit parameter'}), 400
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass


@messages_bp.route('/api/agents/<agent_id>/email', methods=['GET'])
def agent_email(agent_id):
    """
    Get the unique email address for an agent.
    Format: <agent_id>@<console_host>
    The agent_id itself acts as the "password" since it's random.
    """
    import os
    # Use CONSOLE_HOST (same as invite URL hostname)
    domain = os.environ.get('CONSOLE_HOST') or request.host.split(':')[0]

    email = f"{agent_id}@{domain}"

    return jsonify({
        'email': email,
        'agent_id': agent_id
    })


@messages_bp.route('/api/messages/mark-all-read', methods=['POST'])
def mark_all_read():
    """Mark all messages as read, optionally filtered by agent_id."""
    data = request.get_json() or {}
    agent_id = data.get('agent_id')

    conn = get_db_connection()
    try:
        if agent_id == 'unknown':
            conn.execute('UPDATE messages SET read = 1 WHERE agent_id IS NULL')
        elif agent_id:
            conn.execute('UPDATE messages SET read = 1 WHERE agent_id = ?', (agent_id,))
        else:
            conn.execute('UPDATE messages SET read = 1')
        conn.commit()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        conn.close()
