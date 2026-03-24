#!/usr/bin/env python3
"""Interactive web-based game test and debug runner for PICO-8 games.

Runs exported PICO-8 games (HTML/JS) in an interactive test environment with:
- Button input sequencing for reproducible testing
- Session recording (button presses, logs, frame count)
- Deterministic replay of recorded sessions
- Real-time inspection of game logs and state

Usage:
  python3 tools/run-interactive-test.py <game_date> [--record] [--replay <session.json>]

Examples:
  # Run interactive test for today's game with recording
  python3 tools/run-interactive-test.py 2026-03-07 --record

  # Replay a recorded session
  python3 tools/run-interactive-test.py 2026-03-07 --replay games/2026-03-07/session_20260307_143022.json

  # Run without recording
  python3 tools/run-interactive-test.py 2026-03-07
"""

import sys
import os
import json
import argparse
import mimetypes
import html
import re
import socket
from pathlib import Path
from datetime import datetime
from http.server import HTTPServer, SimpleHTTPRequestHandler
import webbrowser


class GameTestHandler(SimpleHTTPRequestHandler):
    """HTTP request handler for serving game and test interface."""

    game_dir = None
    game_date = None
    record_mode = False
    replay_data = None

    def do_GET(self):
        """Handle GET requests."""
        if self.path == '/':
            self.serve_test_interface()
        elif self.path == '/api/config':
            self.serve_config()
        else:
            # Serve game files (game.html, game.js, and other resources)
            self.serve_game_file()

    def do_POST(self):
        """Handle POST requests for session recording."""
        if self.path == '/api/session/save':
            self.save_session()
        else:
            self.send_error(404)

    def serve_test_interface(self):
        """Serve the interactive test interface HTML."""
        html = self.generate_test_interface_html()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', len(html))
        self.end_headers()
        self.wfile.write(html.encode())

    def serve_config(self):
        """Serve configuration for the test interface."""
        config = {
            'game_date': self.game_date,
            'record_mode': self.record_mode,
            'replay_mode': self.replay_data is not None,
            'replay_data': self.replay_data
        }
        response_json = json.dumps(config)
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(response_json))
        self.end_headers()
        self.wfile.write(response_json.encode())

    def serve_game_file(self):
        """Serve static files from the game directory."""
        # Extract the file path, prevent path traversal attacks
        file_path = os.path.normpath(self.path.lstrip('/'))
        if '..' in file_path or file_path.startswith('/'):
            self.send_error(403, "Access denied")
            return

        full_path = os.path.join(self.game_dir, file_path)

        # Ensure the resolved path is still within game_dir
        real_game_dir = os.path.realpath(self.game_dir)
        real_full_path = os.path.realpath(full_path)
        if not real_full_path.startswith(real_game_dir):
            self.send_error(403, "Access denied")
            return

        if not os.path.exists(full_path):
            self.send_error(404, f"File not found: {file_path}")
            return

        if not os.path.isfile(full_path):
            self.send_error(403, "Access denied")
            return

        try:
            with open(full_path, 'rb') as f:
                content = f.read()

            # Determine content type
            content_type, _ = mimetypes.guess_type(full_path)
            if not content_type:
                content_type = 'application/octet-stream'

            self.send_response(200)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', len(content))
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            self.send_error(500, f"Failed to serve file: {str(e)}")

    def save_session(self):
        """Save recorded session data."""
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length == 0:
            self.send_error(400, "No data")
            return

        try:
            body = self.rfile.read(content_length)
            session_data = json.loads(body.decode())

            # Ensure sessions directory exists
            sessions_dir = self.game_dir
            os.makedirs(sessions_dir, exist_ok=True)

            # Generate session filename
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            session_file = os.path.join(sessions_dir, f'session_{timestamp}.json')

            # Write session file
            with open(session_file, 'w') as f:
                json.dump(session_data, f, indent=2)

            # Send success response
            response = {'status': 'ok', 'session_file': session_file}
            response_json = json.dumps(response)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(response_json))
            self.end_headers()
            self.wfile.write(response_json.encode())

            print(f"💾 Session saved: {session_file}")
        except Exception as e:
            self.send_error(500, f"Failed to save session: {str(e)}")

    def generate_test_interface_html(self):
        """Generate the test interface HTML with game in iframe."""
        replay_data_json = ''
        if self.replay_data:
            replay_data_json = json.dumps(self.replay_data)

        return f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PICO-8 Game Test Runner - {self.game_date}</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}

        body {{
            font-family: monospace;
            background: #111;
            color: #aaa;
            padding: 20px;
        }}

        .container {{
            max-width: 1400px;
            margin: 0 auto;
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }}

        .game-section {{
            background: #222;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #333;
        }}

        .log-section {{
            background: #222;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #333;
            display: flex;
            flex-direction: column;
        }}

        h1 {{
            color: #fff;
            margin-bottom: 20px;
            font-size: 18px;
        }}

        .game-iframe {{
            border: 2px solid #555;
            background: #000;
            width: 100%;
            height: 400px;
            margin-bottom: 20px;
        }}

        .game-info {{
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 10px;
            margin-bottom: 20px;
            font-size: 12px;
        }}

        .info-item {{
            background: #111;
            padding: 8px;
            border-radius: 4px;
            border-left: 3px solid #666;
        }}

        .info-label {{
            color: #888;
            font-size: 10px;
            text-transform: uppercase;
        }}

        .info-value {{
            color: #0f0;
            font-weight: bold;
        }}

        .button-pad {{
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 8px;
            margin-bottom: 20px;
        }}

        .button {{
            padding: 12px;
            border: 2px solid #555;
            background: #333;
            color: #aaa;
            cursor: pointer;
            border-radius: 4px;
            font-weight: bold;
            transition: all 0.1s;
            font-size: 12px;
            touch-action: none;
        }}

        .button:hover {{
            background: #444;
            border-color: #666;
        }}

        .button.pressed {{
            background: #0f0;
            color: #000;
            border-color: #0f0;
        }}

        .controls {{
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
        }}

        .btn-primary {{
            flex: 1;
            padding: 10px;
            background: #0a4;
            color: #000;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-weight: bold;
            font-family: monospace;
        }}

        .btn-primary:hover {{
            background: #0b5;
        }}

        .btn-primary:disabled {{
            background: #666;
            color: #aaa;
            cursor: not-allowed;
        }}

        .log-viewer {{
            flex: 1;
            background: #111;
            border: 1px solid #444;
            border-radius: 4px;
            padding: 10px;
            font-size: 11px;
            font-family: monospace;
            overflow-y: auto;
            line-height: 1.4;
        }}

        .log-entry {{
            margin-bottom: 4px;
            padding: 2px 4px;
        }}

        .log-entry.state {{
            color: #0f0;
        }}

        .log-entry.event {{
            color: #0ff;
        }}

        .status {{
            padding: 10px;
            border-radius: 4px;
            margin-bottom: 10px;
            font-size: 12px;
            display: none;
        }}

        .status.show {{
            display: block;
        }}

        .status.recording {{
            background: #600;
            color: #f00;
        }}

        .status.success {{
            background: #060;
            color: #0f0;
        }}

        @media (max-width: 1024px) {{
            .container {{
                grid-template-columns: 1fr;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="game-section">
            <h1>Game: {html.escape(self.game_date)}</h1>

            <div class="game-info">
                <div class="info-item">
                    <div class="info-label">Frame</div>
                    <div class="info-value" id="frame-count">0</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Mode</div>
                    <div class="info-value" id="test-mode">{'Replay' if self.replay_data else 'Record' if self.record_mode else 'View'}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Logs</div>
                    <div class="info-value" id="log-count">0</div>
                </div>
            </div>

            <iframe id="game-iframe" class="game-iframe" src="/game.html" title="PICO-8 Game"></iframe>

            <div class="button-pad">
                <button class="button" data-button="left" title="Arrow Left / A">←</button>
                <button class="button" data-button="up" title="Arrow Up / W">↑</button>
                <button class="button" data-button="right" title="Arrow Right / D">→</button>
                <button class="button" data-button="down" title="Arrow Down / S">↓</button>
                <button class="button" data-button="o" title="Z / C">O</button>
                <button class="button" data-button="x" title="X / V">X</button>
            </div>

            <div class="controls">
                <button class="btn-primary" id="reset-btn">Reset Game</button>
                <button class="btn-primary" id="record-btn">{'Stop Recording' if self.record_mode else 'Record Session'}</button>
            </div>

            <div class="status" id="status-msg"></div>
        </div>

        <div class="log-section">
            <h1>Real-Time Logs</h1>
            <div class="log-viewer" id="log-viewer"></div>
        </div>
    </div>

    <script>
        const buttonBits = {{
            'left': 0x01,
            'right': 0x02,
            'up': 0x04,
            'down': 0x08,
            'o': 0x10,
            'x': 0x20
        }};

        let recordedInputs = [];
        let recordedLogs = [];
        let buttonStates = {{
            'left': false,
            'right': false,
            'up': false,
            'down': false,
            'o': false,
            'x': false
        }};

        let frameCount = 0;
        let isRecording = {str(self.record_mode).lower()};
        let replayMode = {str(self.replay_data is not None).lower()};
        let replayInputs = {json.dumps(self.replay_data.get('button_sequence', []) if self.replay_data else [])};
        let replayLogs = {json.dumps(self.replay_data.get('logs', []) if self.replay_data else [])};
        let gameFrame = null;
        let lastLogCount = 0;

        // Wait for iframe to load
        const iframe = document.getElementById('game-iframe');
        iframe.onload = function() {{
            gameFrame = iframe.contentWindow;
            console.log('Game frame loaded');

            // Enable test mode and initialize test infrastructure
            if (gameFrame) {{
                gameFrame.testmode = true;
                // Initialize test_log if it doesn't exist
                if (!gameFrame.test_log) {{
                    gameFrame.test_log = [];
                }}
                // Initialize test_inputs if it doesn't exist
                if (!gameFrame.test_inputs) {{
                    gameFrame.test_inputs = [];
                }}
                // Reset test_input_idx to 0
                gameFrame.test_input_idx = 0;
                console.log('Test mode enabled: testmode=' + gameFrame.testmode);
            }}

            statusMessage('Game loaded. Use arrow keys or buttons to interact.', 'success');
            startUpdateLoop();
        }};

        function startUpdateLoop() {{
            setInterval(updateFrame, 16.67); // ~60 FPS
        }}

        function updateFrame() {{
            if (!gameFrame) {{
                console.warn('Game frame not accessible');
                return;
            }}

            // Safety check for pico8_buttons array
            if (!gameFrame.pico8_buttons) {{
                if (frameCount === 0) {{
                    statusMessage('Game loaded but pico8_buttons not found', 'error');
                }}
                return;
            }}

            frameCount++;
            document.getElementById('frame-count').textContent = frameCount;

            // Set button input
            try {{
                if (replayMode && frameCount - 1 < replayInputs.length) {{
                    gameFrame.pico8_buttons[0] = replayInputs[frameCount - 1] || 0;
                }} else {{
                    gameFrame.pico8_buttons[0] = calculateButtonState();
                }}
            }} catch (e) {{
                console.error('Failed to set buttons:', e);
            }}

            // Check for new logs
            try {{
                const testLog = gameFrame.test_log;
                if (testLog && Array.isArray(testLog) && testLog.length > lastLogCount) {{
                    const newLogs = testLog.slice(lastLogCount);
                    lastLogCount = testLog.length;

                    newLogs.forEach(log => {{
                        if (typeof log === 'string') {{
                            addLogEntry(log);
                            if (isRecording) {{
                                recordedLogs.push(log);
                            }}
                        }}
                    }});
                }} else if (frameCount === 1) {{
                    // Log diagnostic info on first frame
                    console.log('testmode=' + gameFrame.testmode + ', test_log length=' + (testLog ? testLog.length : 'undefined'));
                }}
            }} catch (e) {{
                console.warn('test_log not accessible:', e);
            }}

            // Record inputs
            if (isRecording) {{
                recordedInputs.push(gameFrame.pico8_buttons[0] || 0);
            }}

            document.getElementById('log-count').textContent = lastLogCount;
        }}

        function calculateButtonState() {{
            let buttonState = 0;
            for (const [btn, bit] of Object.entries(buttonBits)) {{
                if (buttonStates[btn]) {{
                    buttonState |= bit;
                }}
            }}
            return buttonState;
        }}

        function addLogEntry(msg) {{
            const viewer = document.getElementById('log-viewer');
            const entry = document.createElement('div');
            entry.className = 'log-entry';
            if (msg.startsWith('state:')) {{
                entry.classList.add('state');
            }}
            entry.textContent = msg;
            viewer.appendChild(entry);
            viewer.scrollTop = viewer.scrollHeight;
        }}

        function statusMessage(msg, type = 'info') {{
            const statusEl = document.getElementById('status-msg');
            statusEl.textContent = msg;
            statusEl.className = 'status show ' + type;
            if (type === 'success') {{
                setTimeout(() => statusEl.className = 'status', 3000);
            }}
        }}

        // Button event listeners
        document.querySelectorAll('.button').forEach(btn => {{
            btn.addEventListener('mousedown', (e) => {{
                const button = e.target.dataset.button;
                if (button) {{
                    buttonStates[button] = true;
                    e.target.classList.add('pressed');
                }}
            }});

            btn.addEventListener('mouseup', (e) => {{
                const button = e.target.dataset.button;
                if (button) {{
                    buttonStates[button] = false;
                    e.target.classList.remove('pressed');
                }}
            }});
        }});

        // Keyboard input
        const keyMap = {{
            'ArrowLeft': 'left', 'a': 'left', 'A': 'left',
            'ArrowRight': 'right', 'd': 'right', 'D': 'right',
            'ArrowUp': 'up', 'w': 'up', 'W': 'up',
            'ArrowDown': 'down', 's': 'down', 'S': 'down',
            'z': 'o', 'Z': 'o', 'c': 'o', 'C': 'o',
            'x': 'x', 'X': 'x', 'v': 'x', 'V': 'x'
        }};

        document.addEventListener('keydown', (e) => {{
            const button = keyMap[e.key];
            if (button) {{
                buttonStates[button] = true;
                updateButtonUI(button, true);
                e.preventDefault();
            }}
        }});

        document.addEventListener('keyup', (e) => {{
            const button = keyMap[e.key];
            if (button) {{
                buttonStates[button] = false;
                updateButtonUI(button, false);
                e.preventDefault();
            }}
        }});

        function updateButtonUI(button, pressed) {{
            const btn = document.querySelector(`[data-button="${{button}}"]`);
            if (btn) {{
                if (pressed) {{
                    btn.classList.add('pressed');
                }} else {{
                    btn.classList.remove('pressed');
                }}
            }}
        }}

        // Control buttons
        document.getElementById('reset-btn').addEventListener('click', () => {{
            if (gameFrame) {{
                gameFrame.location.reload();
                frameCount = 0;
                recordedInputs = [];
                recordedLogs = [];
                lastLogCount = 0;
                document.getElementById('log-viewer').innerHTML = '';
                document.getElementById('frame-count').textContent = '0';
                statusMessage('Game reset', 'success');
            }}
        }});

        document.getElementById('record-btn').addEventListener('click', () => {{
            if (replayMode) {{
                statusMessage('Cannot record in replay mode', 'error');
                return;
            }}

            isRecording = !isRecording;
            const btn = document.getElementById('record-btn');

            if (isRecording) {{
                recordedInputs = [];
                recordedLogs = [];
                btn.textContent = 'Stop Recording';
                btn.style.background = '#600';
                statusMessage('Recording session...', 'recording');
            }} else {{
                btn.textContent = 'Record Session';
                btn.style.background = '';
                saveSession();
            }}
        }});

        function saveSession() {{
            const sessionData = {{
                'date': '{self.game_date}',
                'timestamp': new Date().toISOString(),
                'duration_frames': frameCount,
                'button_sequence': recordedInputs,
                'logs': recordedLogs,
                'exit_state': 'recorded'
            }};

            fetch('/api/session/save', {{
                method: 'POST',
                headers: {{'Content-Type': 'application/json'}},
                body: JSON.stringify(sessionData)
            }})
            .then(r => r.json())
            .then(data => {{
                statusMessage('Session saved!', 'success');
            }})
            .catch(err => {{
                statusMessage('Failed to save session: ' + err, 'error');
            }});
        }}
    </script>
</body>
</html>
"""

    def log_message(self, format, *args):
        """Override to suppress verbose logging."""
        pass


def find_game_dir(game_date):
    """Find the game directory for a given date."""
    # Validate date format to prevent path traversal
    if not re.match(r'^\d{4}-\d{2}-\d{2}$', game_date):
        return None, f"Invalid game date format. Expected YYYY-MM-DD, got: {game_date}"

    game_dir = os.path.join('games', game_date)

    if not os.path.exists(game_dir):
        return None, f"Game directory not found: {game_dir}"

    if not os.path.exists(os.path.join(game_dir, 'game.html')):
        return None, f"game.html not found in {game_dir}"

    return game_dir, None


def load_replay_session(session_path):
    """Load a recorded session for replay."""
    try:
        with open(session_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Failed to load session: {e}", file=sys.stderr)
        return None


def find_free_port(start_port=8000):
    """Find a free port starting from start_port."""
    for port in range(start_port, start_port + 100):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('127.0.0.1', port))
            return port
        except OSError:
            continue
    return None


def run_server(game_date, game_dir, record_mode, replay_data, port):
    """Run the HTTP server."""
    GameTestHandler.game_dir = game_dir
    GameTestHandler.game_date = game_date
    GameTestHandler.record_mode = record_mode
    GameTestHandler.replay_data = replay_data

    server = HTTPServer(('127.0.0.1', port), GameTestHandler)
    print(f"🎮 Test server running at http://127.0.0.1:{port}")
    print(f"📅 Game: {game_date}")
    mode_str = 'Recording' if record_mode else ('Replay' if replay_data else 'View')
    print(f"📍 Mode: {mode_str}")
    print(f"Press Ctrl+C to stop\n")

    try:
        # Open browser
        try:
            webbrowser.open(f'http://127.0.0.1:{port}')
        except:
            pass

        server.serve_forever()
    except KeyboardInterrupt:
        print("\n⏹️  Server stopped")
        server.shutdown()


def main():
    parser = argparse.ArgumentParser(
        description='Interactive PICO-8 game test runner',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument('game_date', help='Game date (YYYY-MM-DD)')
    parser.add_argument('--record', action='store_true', help='Enable recording mode')
    parser.add_argument('--replay', metavar='SESSION.JSON', help='Replay a recorded session')
    parser.add_argument('--port', type=int, default=8000, help='Port to run server on (default: 8000)')

    args = parser.parse_args()

    # Validate game exists
    game_dir, error = find_game_dir(args.game_date)
    if error:
        print(f"❌ {error}", file=sys.stderr)
        sys.exit(1)

    # Load replay data if specified
    replay_data = None
    if args.replay:
        if not os.path.exists(args.replay):
            print(f"❌ Session file not found: {args.replay}", file=sys.stderr)
            sys.exit(1)
        replay_data = load_replay_session(args.replay)
        if not replay_data:
            sys.exit(1)

    # Find available port
    port = find_free_port(args.port)
    if not port:
        print("❌ Could not find available port", file=sys.stderr)
        sys.exit(1)

    # Run server
    run_server(args.game_date, game_dir, args.record, replay_data, port)


if __name__ == '__main__':
    main()
