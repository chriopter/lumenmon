#!/usr/bin/env python3
"""
Messages API blueprint for SMTP-received messages.
Provides endpoints to list, read, and manage messages per agent.
"""

from flask import Blueprint, jsonify, request
from db import get_db_connection
import secrets
import string

messages_bp = Blueprint('messages', __name__)


def generate_mail_token(length=16):
    """Generate a random mail token for agent email addresses."""
    alphabet = string.ascii_lowercase + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))


@messages_bp.route('/api/messages', methods=['GET'])
def list_all_messages():
    """List all messages, optionally filtered by agent_id or read status."""
    agent_id = request.args.get('agent_id')
    unread_only = request.args.get('unread', '').lower() == 'true'
    limit = int(request.args.get('limit', 100))

    conn = get_db_connection()
    try:
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
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        conn.close()


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
    limit = int(request.args.get('limit', 50))

    conn = get_db_connection()
    try:
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
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        conn.close()


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
