#!/usr/bin/env python3
# Main Flask application entry point that configures templates, static files, and registers blueprints.
# Serves dashboard HTML and proxies API requests. Run directly on port 5000, or via Caddy reverse proxy.

from flask import Flask, jsonify, render_template
from agents import agents_bp
from invites import invites_bp
from management import management_bp
from messages import messages_bp
from db import cleanup_old_metrics
import os
import random
import string
import threading
import time
import json
import urllib.request

# Version cache (fetched from GitHub hourly)
_version_cache = {'version': None, 'checked_at': 0}

# Configure template and static directories
template_dir = os.path.join(os.path.dirname(__file__), '..', 'public', 'html')
static_dir = os.path.join(os.path.dirname(__file__), '..', 'public')
app = Flask(__name__, template_folder=template_dir, static_folder=static_dir, static_url_path='')

# Disable Flask caching
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0

# Register blueprints
app.register_blueprint(agents_bp)
app.register_blueprint(invites_bp)
app.register_blueprint(management_bp)
app.register_blueprint(messages_bp)

# Background cleanup thread for old metrics
def _cleanup_loop():
    """Run cleanup every 5 minutes to keep database size bounded."""
    # Run cleanup immediately at startup to prevent overload from accumulated data
    print("[cleanup] Running initial cleanup...")
    deleted = cleanup_old_metrics()
    if deleted > 0:
        print(f"[cleanup] Initial cleanup deleted {deleted} old metric rows")

    while True:
        time.sleep(300)  # 5 minutes
        deleted = cleanup_old_metrics()
        if deleted > 0:
            print(f"[cleanup] Deleted {deleted} old metric rows")

_cleanup_thread = threading.Thread(target=_cleanup_loop, daemon=True)
_cleanup_thread.start()

@app.route('/', methods=['GET'])
def index():
    """Serve the main dashboard page."""
    # Simple cache-busting: random 6-char version per request
    cache_version = ''.join(random.choices(string.ascii_letters + string.digits, k=6))
    return render_template('index.html', v=cache_version)

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({'status': 'ok', 'service': 'lumenmon-api'})

@app.route('/api/agent-update', methods=['GET'])
def agent_update_script():
    """Serve shell script to update agent certificate."""
    from flask import request, Response
    host = os.environ.get('CONSOLE_HOST') or request.host.split(':')[0]
    script = f'''#!/bin/bash
H={host}
D=/opt/lumenmon/agent/data/mqtt
openssl s_client -connect $H:8884 </dev/null 2>/dev/null | openssl x509 > $D/server.crt
openssl x509 -in $D/server.crt -noout -fingerprint -sha256 | cut -d= -f2 > $D/fingerprint
echo $H > $D/host
curl -sS "$H:8080/api/agent-sync?id=$(cat $D/username)&pw=$(cat $D/password)"
systemctl restart lumenmon-agent
echo "Updated to $H"
'''
    return Response(script, mimetype='text/plain')

@app.route('/api/agent-sync', methods=['GET'])
def agent_sync():
    """Sync agent password to MQTT broker."""
    from flask import request
    import subprocess
    agent_id = request.args.get('id')
    password = request.args.get('pw')
    if not agent_id or not password:
        return jsonify({'error': 'missing id or pw'}), 400
    # Update password in mosquitto
    try:
        subprocess.run([
            'mosquitto_passwd', '-b', '/data/mqtt/passwd', agent_id, password
        ], check=True)
        subprocess.run(['pkill', '-HUP', 'mosquitto'], check=False)
        return jsonify({'status': 'ok', 'agent': agent_id})
    except Exception:
        return jsonify({'error': 'Failed to sync agent'}), 500

@app.route('/api/version/latest', methods=['GET'])
def latest_version():
    """Returns latest release version from GitHub (cached hourly)."""
    now = time.time()
    if now - _version_cache['checked_at'] > 3600:  # 1 hour cache
        try:
            req = urllib.request.Request(
                'https://api.github.com/repos/chriopter/lumenmon/releases/latest',
                headers={'User-Agent': 'lumenmon-console'}
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = json.loads(resp.read().decode())
                _version_cache['version'] = data.get('tag_name')
                _version_cache['checked_at'] = now
        except Exception:
            pass  # Keep old cached value on error
    return jsonify({'version': _version_cache['version']})

@app.route('/api', methods=['GET'])
def api_info():
    """API information and available endpoints."""
    return jsonify({
        'service': 'lumenmon-api',
        'version': '0.1',
        'endpoints': {
            'agents': '/api/agents',
            'invites': {
                'list': '/api/invites',
                'create': '/api/invites/create',
                'create_full': '/api/invites/create/full'
            },
            'messages': {
                'list': '/api/messages',
                'unread_counts': '/api/messages/unread-counts',
                'agent_messages': '/api/agents/{agent_id}/messages',
                'agent_email': '/api/agents/{agent_id}/email'
            },
            'health': '/health'
        }
    })

if __name__ == '__main__':
    # Run Flask server
    print("[flask] Starting Lumenmon API server on port 5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
