#!/usr/bin/env python3
"""Convert recorded PICO-8 game sessions into animated GIFs.

This tool reads session JSON files (produced by run-interactive-test.py with --record flag)
and generates animated GIFs showing the complete gameplay.

Usage:
  python3 tools/export-session-gif.py <game_date> [--session <session_file.json>] [--fps 30] [--output <output.gif>]

Examples:
  # Export latest session from a game
  python3 tools/export-session-gif.py 2026-03-08

  # Export a specific session
  python3 tools/export-session-gif.py 2026-03-08 --session games/2026-03-08/session_20260308_123456.json

  # Custom FPS and output
  python3 tools/export-session-gif.py 2026-03-08 --fps 15 --output my_game.gif
"""

import sys
import os
import json
import argparse
import re
import subprocess
import base64
import tempfile
import time
import http.server
import socketserver
import threading
import socket
from pathlib import Path
from datetime import datetime
from typing import List, Tuple, Optional
from io import BytesIO

try:
    from PIL import Image
except ImportError:
    print("❌ PIL/Pillow not found. Install with: pip install Pillow", file=sys.stderr)
    sys.exit(1)


def find_game_dir(game_date: str) -> Tuple[Optional[str], Optional[str]]:
    """Find the game directory for a given date."""
    if not re.match(r'^\d{4}-\d{2}-\d{2}$', game_date):
        return None, f"Invalid game date format. Expected YYYY-MM-DD, got: {game_date}"

    game_dir = os.path.join('games', game_date)

    if not os.path.exists(game_dir):
        return None, f"Game directory not found: {game_dir}"

    if not os.path.exists(os.path.join(game_dir, 'game.html')):
        return None, f"game.html not found in {game_dir}"

    return game_dir, None


def find_latest_session(game_dir: str) -> Optional[str]:
    """Find the latest session file in a game directory."""
    session_files = sorted(
        [f for f in os.listdir(game_dir) if f.startswith('session_') and f.endswith('.json') and '_' in f[8:]],
        reverse=True
    )
    if session_files:
        return os.path.join(game_dir, session_files[0])
    return None


def load_session(session_path: str) -> Tuple[Optional[dict], Optional[str]]:
    """Load a session JSON file."""
    try:
        with open(session_path, 'r') as f:
            data = json.load(f)

        # Validate session structure
        if not isinstance(data, dict):
            return None, "Session must be a JSON object"

        required = ['button_sequence', 'duration_frames', 'date']
        missing = [k for k in required if k not in data]
        if missing:
            return None, f"Missing required fields: {', '.join(missing)}"

        if not isinstance(data['button_sequence'], list):
            return None, "button_sequence must be an array"

        if not isinstance(data['duration_frames'], int) or data['duration_frames'] <= 0:
            return None, "duration_frames must be a positive integer"

        return data, None
    except json.JSONDecodeError as e:
        return None, f"Invalid JSON: {e}"
    except Exception as e:
        return None, f"Failed to load session: {e}"


def calculate_frame_compression(duration_frames: int) -> int:
    """Calculate frame skip rate for long sessions.

    For sessions longer than 30 seconds (1800 frames at 60fps):
    - Skip every nth frame to keep GIF reasonable size
    - Keep compression ratio <= 4x (min 15 fps effective)
    """
    max_frames_per_session = 1800  # 30 seconds at 60fps
    if duration_frames <= max_frames_per_session:
        return 1  # No skipping

    # Calculate skip rate (at minimum 15fps effective)
    skip_rate = int(duration_frames / max_frames_per_session)
    return min(skip_rate, 4)  # Cap at 4x compression (15fps minimum)


def capture_game_frames(game_dir: str, session: dict, fps: int = 30) -> Tuple[Optional[List], Optional[str]]:
    """Capture game frames using Chromium and an injected frame capture handler."""
    button_sequence = session.get('button_sequence', [])
    duration_frames = session.get('duration_frames', len(button_sequence))

    # Calculate frame compression
    frame_skip = calculate_frame_compression(duration_frames)

    # Create a capture handler that will receive frame data from the browser
    frames = {}
    frames_lock = threading.Lock()
    server_ready = threading.Event()
    capture_complete = threading.Event()

    class FrameCaptureHandler(http.server.SimpleHTTPRequestHandler):
        def do_GET(self):
            if self.path == '/':
                self.serve_game_page()
            elif self.path == '/health':
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', 15)
                self.end_headers()
                self.wfile.write(b'{"status":"ok"}')
            else:
                self.send_error(404)

        def do_POST(self):
            if self.path == '/capture-frame':
                content_length = int(self.headers.get('Content-Length', 0))
                if content_length > 0:
                    try:
                        body = self.rfile.read(content_length)
                        data = json.loads(body.decode())
                        frame_idx = data.get('frame_idx')
                        image_data = data.get('image')

                        with frames_lock:
                            if frame_idx is not None and image_data:
                                frames[frame_idx] = image_data

                        self.send_response(200)
                        self.send_header('Content-Type', 'application/json')
                        self.send_header('Content-Length', 15)
                        self.end_headers()
                        self.wfile.write(b'{"status":"ok"}')
                    except Exception as e:
                        self.send_error(400)
                else:
                    self.send_error(400)
            else:
                self.send_error(404)

        def serve_game_page(self):
            """Serve the game with frame capture injected."""
            game_html_path = os.path.join(game_dir, 'game.html')

            try:
                with open(game_html_path, 'r') as f:
                    html_content = f.read()
            except Exception as e:
                self.send_error(500, f"Failed to read game.html: {e}")
                return

            # Create wrapper HTML with frame capture
            wrapper = _create_wrapper_html(html_content, button_sequence, duration_frames, frame_skip)

            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', len(wrapper))
            self.end_headers()
            self.wfile.write(wrapper.encode())

        def log_message(self, format, *args):
            pass  # Suppress logging

    # Find free port
    def find_free_port():
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('127.0.0.1', 0))
            return s.getsockname()[1]

    port = find_free_port()
    url = f"http://127.0.0.1:{port}"

    # Start HTTP server
    with socketserver.TCPServer(("127.0.0.1", port), FrameCaptureHandler) as httpd:
        server_thread = threading.Thread(target=httpd.serve_forever, daemon=True)
        server_thread.start()

        print(f"🌐 HTTP server on {url}")

        try:
            # Give server time to start
            time.sleep(0.5)

            # Launch Chromium
            print(f"🎥 Launching Chromium...")
            cmd = [
                '/usr/bin/chromium',
                '--headless=new',
                '--disable-gpu',
                '--no-sandbox',
                '--disable-dev-shm-usage',
                '--no-first-run',
                '--no-default-browser-check',
                '--disable-extensions',
                '--disable-background-networking',
                '--disable-breakpad',
                '--disable-client-side-phishing-detection',
                '--disable-default-apps',
                '--disable-hang-monitor',
                '--disable-popup-blocking',
                '--disable-prompt-on-repost',
                '--disable-sync',
                '--enable-automation',
                url
            ]

            # Calculate timeout based on session length
            timeout_sec = max(30, int(duration_frames * 20 / 1000) + 10)

            result = subprocess.run(
                cmd,
                capture_output=True,
                timeout=timeout_sec,
                text=True
            )

            # Give server time to process final requests
            time.sleep(1)

            # Convert captured frames to PIL images
            result_frames = []
            if frames:
                print(f"  Converting {len(frames)} frames...")
                for idx in sorted(frames.keys()):
                    try:
                        b64_data = frames[idx]
                        if b64_data and isinstance(b64_data, str):
                            # Remove data URL prefix if present
                            if ',' in b64_data:
                                b64_data = b64_data.split(',', 1)[1]

                            img_data = base64.b64decode(b64_data)
                            img = Image.open(BytesIO(img_data))
                            result_frames.append(img.convert('RGB'))

                            if (len(result_frames)) % 10 == 0:
                                print(f"    📸 Decoded {len(result_frames)} frames")
                    except Exception as e:
                        print(f"    ⚠️  Failed to decode frame {idx}: {e}")

            if not result_frames:
                return None, "No frames captured"

            print(f"✅ Captured {len(result_frames)} frames")
            return result_frames, None

        except subprocess.TimeoutExpired:
            return None, f"Chromium timed out after {timeout_sec}s (session may be too long)"
        except FileNotFoundError:
            return None, "Chromium not found at /usr/bin/chromium"
        except Exception as e:
            return None, f"Frame capture error: {e}"
        finally:
            httpd.shutdown()


def _create_wrapper_html(original_html: str, button_sequence: list, duration_frames: int, frame_skip: int) -> str:
    """Create wrapper HTML with frame capture functionality."""
    buttons_json = json.dumps(button_sequence)

    capture_script = f"""
<script>
(function() {{
    const buttons = {buttons_json};
    const durationFrames = {duration_frames};
    const frameSkip = {frame_skip};
    let frameCount = 0;
    let capturedCount = 0;

    function captureAndSend() {{
        try {{
            const canvas = document.querySelector('canvas');
            if (!canvas) return;

            const dataUrl = canvas.toDataURL('image/png');
            fetch('/capture-frame', {{
                method: 'POST',
                headers: {{'Content-Type': 'application/json'}},
                body: JSON.stringify({{
                    frame_idx: capturedCount,
                    image: dataUrl
                }})
            }}).catch(e => console.warn('Failed to send frame:', e));

            capturedCount++;
        }} catch(e) {{
            console.warn('Capture error:', e);
        }}
    }}

    function simulateFrame() {{
        if (frameCount >= durationFrames) {{
            console.log('Simulation complete:', capturedCount, 'frames captured');
            return;
        }}

        // Set button input for this frame
        if (frameCount < buttons.length && typeof pico8_buttons !== 'undefined') {{
            pico8_buttons[0] = buttons[frameCount];
        }}

        // Capture every Nth frame
        if ((frameCount + 1) % frameSkip === 0) {{
            captureAndSend();
        }}

        frameCount++;
        setTimeout(simulateFrame, 16.67);  // ~60 FPS
    }}

    // Wait for PICO-8 to initialize
    let initAttempts = 0;
    const initInterval = setInterval(() => {{
        if (typeof pico8_buttons !== 'undefined' && pico8_buttons.length > 0) {{
            clearInterval(initInterval);
            console.log('PICO-8 initialized, starting frame capture');
            setTimeout(simulateFrame, 100);
        }} else if (++initAttempts > 50) {{
            clearInterval(initInterval);
            console.error('PICO-8 not initialized after 5 seconds');
        }}
    }}, 100);
}})();
</script>
"""

    # Insert capture script before closing body tag
    if '</body>' in original_html:
        return original_html.replace('</body>', capture_script + '</body>')
    else:
        return original_html + capture_script


def create_gif(frames: List, output_path: str, fps: int = 30, frame_skip: int = 1) -> Optional[str]:
    """Create animated GIF from frame list."""
    if not frames or len(frames) == 0:
        return "No frames to create GIF"

    try:
        # Calculate effective FPS
        effective_fps = fps / frame_skip if frame_skip > 1 else fps
        duration_ms = int(1000 / effective_fps)

        # Ensure output directory exists
        os.makedirs(os.path.dirname(output_path) or '.', exist_ok=True)

        # Save as animated GIF
        frames[0].save(
            output_path,
            save_all=True,
            append_images=frames[1:] if len(frames) > 1 else [],
            duration=duration_ms,
            loop=0,
            optimize=False
        )

        file_size_mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"💾 GIF saved: {output_path} ({file_size_mb:.2f} MB)")
        return None

    except Exception as e:
        return f"GIF creation failed: {e}"


def update_assessment(game_dir: str, gif_filename: str) -> Optional[str]:
    """Add GIF reference to assessment.md if it exists."""
    assessment_path = os.path.join(game_dir, 'assessment.md')

    if not os.path.exists(assessment_path):
        return None

    try:
        with open(assessment_path, 'r') as f:
            content = f.read()

        if gif_filename in content:
            return None

        if content and not content.endswith('\n'):
            content += '\n'

        content += f"\n## Session Recording\n\n![session-gif]({gif_filename})\n"

        with open(assessment_path, 'w') as f:
            f.write(content)

        print(f"✏️  Updated assessment.md with GIF reference")
        return None

    except Exception as e:
        return f"Failed to update assessment.md: {e}"


def main():
    parser = argparse.ArgumentParser(
        description='Convert recorded PICO-8 game sessions into animated GIFs',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument('game_date', help='Game date (YYYY-MM-DD)')
    parser.add_argument('--session', help='Path to session JSON file (default: latest)')
    parser.add_argument('--fps', type=int, default=30, help='Target FPS for GIF (default: 30)')
    parser.add_argument('--output', help='Output GIF path (default: games/YYYY-MM-DD/session_<timestamp>.gif)')

    args = parser.parse_args()

    # Find game directory
    game_dir, error = find_game_dir(args.game_date)
    if error:
        print(f"❌ {error}", file=sys.stderr)
        return 1

    print(f"📂 Game directory: {game_dir}")

    # Find session file
    if args.session:
        session_path = args.session
        if not os.path.exists(session_path):
            print(f"❌ Session file not found: {session_path}", file=sys.stderr)
            return 1
    else:
        session_path = find_latest_session(game_dir)
        if not session_path:
            print(f"❌ No session files found in {game_dir}", file=sys.stderr)
            return 1

    print(f"📋 Session file: {session_path}")

    # Load session
    session, error = load_session(session_path)
    if error:
        print(f"❌ {error}", file=sys.stderr)
        return 1

    print(f"📊 Session: {session['duration_frames']} frames, {len(session['button_sequence'])} inputs")

    # Calculate output path
    if args.output:
        output_path = args.output
    else:
        timestamp = session.get('timestamp', '')
        if timestamp:
            try:
                dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                timestamp_str = dt.strftime('%Y%m%d_%H%M%S')
            except:
                timestamp_str = datetime.now().strftime('%Y%m%d_%H%M%S')
        else:
            timestamp_str = datetime.now().strftime('%Y%m%d_%H%M%S')

        output_path = os.path.join(game_dir, f'session_{timestamp_str}.gif')

    print(f"🎬 Output: {output_path}")

    # Validate FPS
    if args.fps < 10 or args.fps > 60:
        print(f"⚠️  FPS {args.fps} outside typical range (10-60)", file=sys.stderr)

    # Calculate frame compression
    frame_skip = calculate_frame_compression(session['duration_frames'])
    if frame_skip > 1:
        print(f"⏫ Compressing long session by {frame_skip}x (every {frame_skip} frames)")

    # Capture frames
    print(f"🎥 Capturing frames...")
    frames, error = capture_game_frames(game_dir, session, args.fps)
    if error:
        print(f"❌ {error}", file=sys.stderr)
        return 1

    # Create GIF
    print(f"🎨 Creating GIF...")
    error = create_gif(frames, output_path, args.fps, frame_skip)
    if error:
        print(f"❌ {error}", file=sys.stderr)
        return 1

    # Update assessment
    gif_filename = os.path.basename(output_path)
    update_assessment(game_dir, gif_filename)

    print(f"✅ Done! GIF created: {output_path}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
