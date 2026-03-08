#!/usr/bin/env python3
"""Analytics dashboard server for PICO-8 games.

Provides HTTP API for game analytics and serves interactive dashboard UI.

Endpoints:
  GET  /                    - Dashboard UI
  GET  /api/analytics       - Master analytics report
  GET  /api/games           - List of all games
  GET  /api/games/<date>    - Per-game analytics
  GET  /api/games/<date>/sessions - Sessions for a game
"""

import os
import sys
import json
import argparse
import socket
import re
from pathlib import Path
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import webbrowser

# Add tools directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from analytics_engine import (
    generate_analytics_report,
    find_all_games,
    calculate_game_metrics,
    find_sessions,
    load_session
)


class AnalyticsDashboardHandler(SimpleHTTPRequestHandler):
    """HTTP handler for analytics dashboard."""

    dashboard_dir = None

    def do_GET(self):
        """Handle GET requests."""
        path = urlparse(self.path).path

        try:
            if path == '/':
                self.serve_dashboard()
            elif path == '/api/analytics':
                self.serve_master_analytics()
            elif path == '/api/games':
                self.serve_games_list()
            elif path.startswith('/api/games/'):
                self.serve_game_analytics(path)
            elif path.endswith('.js'):
                self.serve_static_file(path)
            elif path.endswith('.css'):
                self.serve_static_file(path)
            else:
                self.send_error(404, 'Not found')
        except Exception as e:
            self.send_json({'error': str(e)}, status=500)

    def serve_dashboard(self):
        """Serve dashboard HTML."""
        dashboard_file = os.path.join(self.dashboard_dir, 'index.html')

        if not os.path.exists(dashboard_file):
            self.send_error(404, 'Dashboard not found')
            return

        try:
            with open(dashboard_file, 'r') as f:
                html_content = f.read()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', len(html_content))
            self.end_headers()
            self.wfile.write(html_content.encode())
        except IOError as e:
            self.send_error(500, str(e))

    def serve_master_analytics(self):
        """Serve master analytics report."""
        try:
            # Check if cached report exists
            analytics_file = os.path.join('games', 'analytics-report.json')
            if os.path.exists(analytics_file):
                with open(analytics_file, 'r') as f:
                    data = json.load(f)
            else:
                # Generate fresh report
                data = generate_analytics_report()

            self.send_json(data, status=200)
        except Exception as e:
            self.send_json({'error': str(e)}, status=500)

    def serve_games_list(self):
        """Serve list of all games with basic info."""
        try:
            games = find_all_games()
            games_data = []

            for date, game_dir in games:
                # Get basic info
                test_report = None
                test_report_path = os.path.join(game_dir, 'test-report.json')
                if os.path.exists(test_report_path):
                    try:
                        with open(test_report_path, 'r') as f:
                            test_report = json.load(f)
                    except (json.JSONDecodeError, IOError):
                        pass

                analytics = calculate_game_metrics(game_dir, date)

                games_data.append({
                    'date': date,
                    'test_status': test_report.get('status') if test_report else None,
                    'has_sessions': analytics.get('has_sessions', False) if analytics else False,
                    'session_count': analytics.get('session_count', 0) if analytics else 0,
                })

            self.send_json({'games': games_data}, status=200)
        except Exception as e:
            self.send_json({'error': str(e)}, status=500)

    def serve_game_analytics(self, path):
        """Serve analytics for a specific game.

        Path format: /api/games/<date> or /api/games/<date>/sessions
        """
        parts = path.strip('/').split('/')

        if len(parts) < 3:
            self.send_error(404, 'Not found')
            return

        date = parts[2]

        # Validate date format (YYYY-MM-DD) to prevent path traversal
        if not re.match(r'^\d{4}-\d{2}-\d{2}$', date):
            self.send_error(404, f'Game {date} not found')
            return

        try:
            game_dir = os.path.join('games', date)
            if not os.path.isdir(game_dir):
                self.send_error(404, f'Game {date} not found')
                return

            # Check if requesting sessions
            if len(parts) > 3 and parts[3] == 'sessions':
                self.serve_game_sessions(game_dir, date)
            else:
                # Serve per-game analytics
                analytics = calculate_game_metrics(game_dir, date)
                if analytics:
                    self.send_json(analytics, status=200)
                else:
                    self.send_json({'error': 'No analytics data'}, status=404)

        except Exception as e:
            self.send_json({'error': str(e)}, status=500)

    def serve_game_sessions(self, game_dir, date):
        """Serve list of sessions for a game."""
        try:
            sessions = find_sessions(game_dir)
            sessions_data = []

            for session_path, session, mtime in sessions:
                sessions_data.append({
                    'filename': os.path.basename(session_path),
                    'duration_frames': session.get('duration_frames', 0),
                    'exit_state': session.get('exit_state', 'unknown'),
                    'logs_count': len(session.get('logs', [])),
                    'timestamp': session.get('timestamp', 'unknown')
                })

            self.send_json({'date': date, 'sessions': sessions_data}, status=200)
        except Exception as e:
            self.send_json({'error': str(e)}, status=500)

    def serve_static_file(self, path):
        """Serve static files (JS, CSS) from dashboard directory."""
        file_path = path.lstrip('/')
        full_path = os.path.join(self.dashboard_dir, file_path)

        # Security: prevent path traversal
        real_dashboard = os.path.realpath(self.dashboard_dir)
        real_file = os.path.realpath(full_path)
        if not real_file.startswith(real_dashboard):
            self.send_error(403, 'Access denied')
            return

        if not os.path.exists(full_path):
            self.send_error(404, 'File not found')
            return

        try:
            with open(full_path, 'rb') as f:
                content = f.read()

            mime_type = 'text/javascript' if path.endswith('.js') else 'text/css'
            self.send_response(200)
            self.send_header('Content-Type', mime_type)
            self.send_header('Content-Length', len(content))
            self.end_headers()
            self.wfile.write(content)
        except IOError as e:
            self.send_error(500, str(e))

    def send_json(self, data, status=200):
        """Send JSON response."""
        json_str = json.dumps(data, indent=2)
        json_bytes = json_str.encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', len(json_bytes))
        self.end_headers()
        self.wfile.write(json_bytes)

    def log_message(self, format, *args):
        """Suppress default logging."""
        return


def find_free_port(start_port=8000, max_port=8100):
    """Find a free port to bind to."""
    for port in range(start_port, max_port):
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.bind(('127.0.0.1', port))
            sock.close()
            return port
        except OSError:
            continue
    return None


def main():
    """Start analytics dashboard server."""
    parser = argparse.ArgumentParser(
        description='Analytics dashboard for PICO-8 games'
    )
    parser.add_argument(
        '--port',
        type=int,
        default=8000,
        help='Port to run server on (default: 8000, auto-find if taken)'
    )
    parser.add_argument(
        '--host',
        default='127.0.0.1',
        help='Host to bind to (default: 127.0.0.1)'
    )
    parser.add_argument(
        '--no-browser',
        action='store_true',
        help='Do not open browser automatically'
    )

    args = parser.parse_args()

    # Find dashboard directory
    dashboard_dir = os.path.join(os.path.dirname(__file__), 'dashboard')
    if not os.path.isdir(dashboard_dir):
        print(f"Error: Dashboard directory not found at {dashboard_dir}")
        sys.exit(1)

    # Find available port
    port = args.port
    if not is_port_free(args.host, port):
        port = find_free_port(args.port)
        if port is None:
            print(f"Error: Could not find free port")
            sys.exit(1)

    AnalyticsDashboardHandler.dashboard_dir = dashboard_dir

    # Start server
    server_address = (args.host, port)
    httpd = HTTPServer(server_address, AnalyticsDashboardHandler)

    url = f'http://{args.host}:{port}/'
    print(f'Analytics dashboard running at {url}')
    print('Press Ctrl+C to stop')

    # Open browser if requested
    if not args.no_browser:
        try:
            webbrowser.open(url)
        except Exception:
            pass  # Fail silently if webbrowser fails

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\nShutting down...')
        sys.exit(0)


def is_port_free(host, port):
    """Check if a port is available."""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.bind((host, port))
        sock.close()
        return True
    except OSError:
        return False


if __name__ == '__main__':
    main()
