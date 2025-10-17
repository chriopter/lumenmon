#!/usr/bin/env python3
# Main Flask application entry point that configures templates, static files, and registers blueprints.
# Serves dashboard HTML and proxies API requests. Run directly on port 5000, or via Caddy reverse proxy.

from flask import Flask, jsonify, render_template
from agents import agents_bp
from invites import invites_bp
from debug import debug_bp
import os
import random
import string

# Configure template and static directories
template_dir = os.path.join(os.path.dirname(__file__), '..', 'public', 'html')
static_dir = os.path.join(os.path.dirname(__file__), '..', 'public')
app = Flask(__name__, template_folder=template_dir, static_folder=static_dir, static_url_path='')

# Disable Flask caching
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0

# Register blueprints
app.register_blueprint(agents_bp)
app.register_blueprint(invites_bp)
app.register_blueprint(debug_bp)

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
