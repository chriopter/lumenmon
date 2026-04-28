#!/usr/bin/env python3
"""
Alerting blueprint (webhook mode).
Exposes configuration/status only; does not send outbound alerts yet.
"""

import os
from flask import Blueprint, jsonify

alerts_bp = Blueprint('alerts', __name__)


def env_bool(name, default=False):
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in ('1', 'true', 'yes', 'on')


def mask_webhook(url):
    if not url:
        return ''
    if '://' not in url:
        return 'configured'
    scheme, rest = url.split('://', 1)
    host = rest.split('/', 1)[0]
    return f"{scheme}://{host}/..."


@alerts_bp.route('/api/alerts/status', methods=['GET'])
def alert_status():
    """Return webhook alert configuration status for GUI display."""
    webhook_url = os.environ.get('LUMENMON_ALERT_WEBHOOK_URL', '').strip()
    webhook_enabled = env_bool('LUMENMON_ALERT_WEBHOOK_ENABLED', False)
    dry_run = env_bool('LUMENMON_ALERT_WEBHOOK_DRY_RUN', True)
    auth_header = os.environ.get('LUMENMON_ALERT_WEBHOOK_AUTH_HEADER', '').strip()

    configured = bool(webhook_url)
    mode = 'dry-run' if dry_run else 'active'

    return jsonify({
        'provider': 'webhook',
        'configured': configured,
        'enabled': webhook_enabled,
        'mode': mode,
        'connected': configured and webhook_enabled and not dry_run,
        'destination': mask_webhook(webhook_url),
        'auth_configured': bool(auth_header),
        'note': 'Webhook delivery is not executed by backend yet.'
    })
