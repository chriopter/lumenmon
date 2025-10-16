#!/usr/bin/env python3
# Main Flask application for Lumenmon web interface.
# Imports and registers all reader modules (agents, invites).

from flask import Flask, jsonify
from agents import agents_bp
from invites import invites_bp

app = Flask(__name__)

# Register blueprints
app.register_blueprint(agents_bp)
app.register_blueprint(invites_bp)

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
