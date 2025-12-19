#!/usr/bin/env python3
# Main Flask application entry point that configures templates, static files, and registers blueprints.
# Serves dashboard HTML and proxies API requests. Run directly on port 5000, or via Caddy reverse proxy.

from flask import Flask, jsonify, render_template
from agents import agents_bp
from invites import invites_bp
from management import management_bp
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
            'health': '/health'
        }
    })

if __name__ == '__main__':
    # Run Flask server
    print("[flask] Starting Lumenmon API server on port 5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
