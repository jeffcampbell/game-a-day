#!/usr/bin/env python3
"""Web server for game library discovery and statistics.

Provides a web interface to browse, filter, and sort all games with statistics
dashboard showing genre distribution, difficulty metrics, and playtime analysis.

Usage:
  python3 tools/library-web-server.py [--port PORT]

Options:
  --port PORT    Server port (default: 8000)

Serves:
  - http://127.0.0.1:PORT/         (Game browser)
  - http://127.0.0.1:PORT/stats    (Statistics dashboard)
  - http://127.0.0.1:PORT/api/catalog   (API endpoint)
"""

import os
import sys
import json
import socket
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from pathlib import Path


class GameLibraryHandler(SimpleHTTPRequestHandler):
    """HTTP request handler for game library server."""

    catalog_data = None

    def load_catalog(self):
        """Load catalog.json if needed."""
        if self.catalog_data is None:
            try:
                with open('catalog.json', 'r') as f:
                    self.catalog_data = json.load(f)
            except (IOError, json.JSONDecodeError):
                self.catalog_data = {'games': [], 'statistics': {}}

    def send_json_response(self, data, status=200):
        """Send JSON response."""
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2).encode())

    def send_html_response(self, html, status=200):
        """Send HTML response."""
        self.send_response(status)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())

    def do_GET(self):
        """Handle GET requests."""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        query_params = parse_qs(parsed_path.query)

        if path == '/':
            self.serve_browser()
        elif path == '/stats':
            self.serve_stats()
        elif path == '/api/catalog':
            self.serve_api_catalog(query_params)
        else:
            super().do_GET()

    def serve_browser(self):
        """Serve the game browser page."""
        html = generate_browser_html()
        self.send_html_response(html)

    def serve_stats(self):
        """Serve the statistics dashboard."""
        html = generate_stats_html()
        self.send_html_response(html)

    def serve_api_catalog(self, query_params):
        """Serve catalog API endpoint with optional filtering."""
        self.load_catalog()

        # Extract filter parameters
        games = self.catalog_data.get('games', [])

        # Filter by genre
        if 'genre' in query_params:
            genre = query_params['genre'][0]
            games = [g for g in games if genre in g.get('genres', [])]

        # Filter by difficulty
        if 'difficulty_min' in query_params:
            try:
                min_diff = int(query_params['difficulty_min'][0])
                games = [g for g in games if g.get('difficulty', 3) >= min_diff]
            except ValueError:
                pass

        if 'difficulty_max' in query_params:
            try:
                max_diff = int(query_params['difficulty_max'][0])
                games = [g for g in games if g.get('difficulty', 3) <= max_diff]
            except ValueError:
                pass

        # Filter by completion status
        if 'status' in query_params:
            status = query_params['status'][0]
            games = [g for g in games if g.get('completion_status') == status]

        # Filter by date range
        if 'date_from' in query_params:
            date_from = query_params['date_from'][0]
            games = [g for g in games if g.get('date', '') >= date_from]

        if 'date_to' in query_params:
            date_to = query_params['date_to'][0]
            games = [g for g in games if g.get('date', '') <= date_to]

        # Sort
        sort_by = query_params.get('sort', ['date'])[0]
        reverse = query_params.get('reverse', ['true'])[0].lower() == 'true'

        if sort_by == 'date':
            games.sort(key=lambda g: g.get('date', ''), reverse=reverse)
        elif sort_by == 'title':
            games.sort(key=lambda g: g.get('title', ''), reverse=reverse)
        elif sort_by == 'difficulty':
            games.sort(key=lambda g: g.get('difficulty', 3), reverse=reverse)
        elif sort_by == 'completion_rate':
            games.sort(key=lambda g: g.get('completion_rate', 0), reverse=reverse)
        elif sort_by == 'sessions':
            games.sort(key=lambda g: g.get('sessions_recorded', 0), reverse=reverse)

        response = {
            'total': len(self.catalog_data.get('games', [])),
            'filtered': len(games),
            'games': games,
            'statistics': self.catalog_data.get('statistics', {})
        }

        self.send_json_response(response)

    def log_message(self, format, *args):
        """Suppress verbose logging."""
        pass


def generate_browser_html():
    """Generate the game browser HTML page."""
    return '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Game Library Browser</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
        }

        header {
            background: rgba(255, 255, 255, 0.95);
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        }

        header h1 {
            color: #667eea;
            margin-bottom: 10px;
        }

        header p {
            color: #666;
            font-size: 14px;
        }

        .controls {
            background: rgba(255, 255, 255, 0.95);
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        }

        .filter-group {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 15px;
        }

        .filter-item {
            display: flex;
            flex-direction: column;
        }

        .filter-item label {
            font-size: 12px;
            color: #666;
            margin-bottom: 5px;
            font-weight: 600;
        }

        .filter-item input,
        .filter-item select {
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
        }

        .filter-item input:focus,
        .filter-item select:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }

        .button-group {
            display: flex;
            gap: 10px;
        }

        button {
            padding: 10px 20px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-weight: 600;
            font-size: 14px;
            transition: all 0.3s;
        }

        .btn-primary {
            background: #667eea;
            color: white;
        }

        .btn-primary:hover {
            background: #5568d3;
        }

        .btn-secondary {
            background: #f0f0f0;
            color: #333;
        }

        .btn-secondary:hover {
            background: #e0e0e0;
        }

        .stats-summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }

        .stat-card {
            background: rgba(255, 255, 255, 0.95);
            padding: 15px;
            border-radius: 8px;
            text-align: center;
        }

        .stat-value {
            font-size: 24px;
            font-weight: bold;
            color: #667eea;
        }

        .stat-label {
            font-size: 12px;
            color: #666;
            margin-top: 5px;
        }

        .games-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .game-card {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 10px;
            padding: 20px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
            transition: transform 0.3s, box-shadow 0.3s;
        }

        .game-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.3);
        }

        .game-title {
            font-size: 18px;
            font-weight: bold;
            color: #333;
            margin-bottom: 8px;
        }

        .game-date {
            font-size: 12px;
            color: #999;
            margin-bottom: 10px;
        }

        .game-description {
            font-size: 14px;
            color: #666;
            margin-bottom: 12px;
            line-height: 1.4;
        }

        .game-meta {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-bottom: 12px;
        }

        .badge {
            background: #f0f0f0;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            color: #666;
        }

        .badge-genre {
            background: #e3f2fd;
            color: #1976d2;
        }

        .badge-status {
            background: #f3e5f5;
            color: #7b1fa2;
        }

        .difficulty-stars {
            margin-bottom: 10px;
        }

        .star {
            color: #ffc107;
            font-size: 14px;
        }

        .game-stats {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 8px;
            padding: 10px 0;
            border-top: 1px solid #eee;
            border-bottom: 1px solid #eee;
            margin: 10px 0;
            font-size: 12px;
        }

        .stat {
            color: #666;
        }

        .stat-label {
            font-weight: 600;
            color: #333;
        }

        .game-links {
            display: flex;
            gap: 10px;
            margin-top: 12px;
        }

        .game-links a {
            flex: 1;
            text-align: center;
            padding: 8px;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            font-size: 12px;
            transition: background 0.3s;
        }

        .game-links a:hover {
            background: #5568d3;
        }

        .game-links a.secondary {
            background: #f0f0f0;
            color: #333;
        }

        .game-links a.secondary:hover {
            background: #e0e0e0;
        }

        .loading {
            text-align: center;
            padding: 40px;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 10px;
            color: #666;
        }

        .empty-state {
            text-align: center;
            padding: 40px;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 10px;
            color: #999;
        }

        .footer {
            text-align: center;
            color: rgba(255, 255, 255, 0.8);
            font-size: 12px;
            margin-top: 40px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🎮 Game Library</h1>
            <p>Browse and discover all games created in the game-a-day project</p>
        </header>

        <div class="controls">
            <div class="filter-group">
                <div class="filter-item">
                    <label>Search by Title</label>
                    <input type="text" id="searchTitle" placeholder="e.g. Adventure">
                </div>
                <div class="filter-item">
                    <label>Genre</label>
                    <select id="filterGenre">
                        <option value="">All Genres</option>
                    </select>
                </div>
                <div class="filter-item">
                    <label>Difficulty</label>
                    <select id="filterDifficulty">
                        <option value="">All Difficulties</option>
                        <option value="1">⭐ Very Easy</option>
                        <option value="2">⭐⭐ Easy</option>
                        <option value="3">⭐⭐⭐ Medium</option>
                        <option value="4">⭐⭐⭐⭐ Hard</option>
                        <option value="5">⭐⭐⭐⭐⭐ Very Hard</option>
                    </select>
                </div>
                <div class="filter-item">
                    <label>Status</label>
                    <select id="filterStatus">
                        <option value="">All Statuses</option>
                        <option value="in-progress">In Progress</option>
                        <option value="complete">Complete</option>
                        <option value="polished">Polished</option>
                    </select>
                </div>
                <div class="filter-item">
                    <label>Sort By</label>
                    <select id="sortBy">
                        <option value="date">Date (Newest)</option>
                        <option value="date-old">Date (Oldest)</option>
                        <option value="title">Title (A-Z)</option>
                        <option value="difficulty">Difficulty (Hardest)</option>
                        <option value="completion">Completion Rate</option>
                        <option value="sessions">Sessions Recorded</option>
                    </select>
                </div>
            </div>

            <div class="button-group">
                <button class="btn-primary" onclick="applyFilters()">Apply Filters</button>
                <button class="btn-secondary" onclick="clearFilters()">Clear Filters</button>
                <button class="btn-secondary" onclick="window.location.href = '/stats'">📊 Statistics</button>
            </div>
        </div>

        <div id="summary" class="stats-summary" style="display: none;">
            <div class="stat-card">
                <div class="stat-value" id="summaryTotal">-</div>
                <div class="stat-label">Total Games</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="summaryFiltered">-</div>
                <div class="stat-label">Filtered Games</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="summarySessions">-</div>
                <div class="stat-label">Sessions Recorded</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="summaryCompletion">-</div>
                <div class="stat-label">Avg Completion</div>
            </div>
        </div>

        <div id="gamesList" class="games-grid">
            <div class="loading">Loading games...</div>
        </div>

        <div class="footer">
            Game Library v1.0 | <a href="/stats" style="color: rgba(255,255,255,0.8); text-decoration: none;">View Statistics Dashboard</a>
        </div>
    </div>

    <script>
        let allGames = [];
        let allGenres = new Set();

        async function loadGames() {
            try {
                const response = await fetch('/api/catalog');
                const data = await response.json();
                allGames = data.games || [];

                // Extract genres
                allGames.forEach(game => {
                    (game.genres || []).forEach(g => allGenres.add(g));
                });

                // Populate genre filter
                const genreSelect = document.getElementById('filterGenre');
                Array.from(allGenres).sort().forEach(genre => {
                    const option = document.createElement('option');
                    option.value = genre;
                    option.textContent = genre.charAt(0).toUpperCase() + genre.slice(1);
                    genreSelect.appendChild(option);
                });

                applyFilters();
            } catch (error) {
                document.getElementById('gamesList').innerHTML = '<div class="empty-state">Error loading games</div>';
            }
        }

        function renderStars(difficulty) {
            return '⭐'.repeat(difficulty) + '☆'.repeat(5 - difficulty);
        }

        function renderGameCard(game) {
            const genreTags = (game.genres || [])
                .map(g => `<span class="badge badge-genre">${g}</span>`)
                .join('');

            const statusBadge = game.completion_status
                ? `<span class="badge badge-status">${game.completion_status}</span>`
                : '';

            const gameLinks = `
                <a href="https://pixel-dashboard.local/game/${game.date}/" target="_blank">Play</a>
                ${game.sessions_recorded > 0 ? `<a class="secondary" href="https://pixel-dashboard.local/game/${game.date}/sessions" target="_blank">Sessions (${game.sessions_recorded})</a>` : ''}
            `;

            return `
                <div class="game-card">
                    <div class="game-title">${escapeHtml(game.title)}</div>
                    <div class="game-date">${game.date}</div>
                    <div class="game-description">${escapeHtml(game.description).substring(0, 100)}...</div>

                    <div class="difficulty-stars">${renderStars(game.difficulty)}</div>

                    <div class="game-meta">
                        ${genreTags}
                        ${statusBadge}
                    </div>

                    <div class="game-stats">
                        <div class="stat">
                            <div class="stat-label">Playtime</div>
                            <div>${game.playtime_minutes}m</div>
                        </div>
                        <div class="stat">
                            <div class="stat-label">Completion</div>
                            <div>${(game.completion_rate * 100).toFixed(0)}%</div>
                        </div>
                        <div class="stat">
                            <div class="stat-label">Sessions</div>
                            <div>${game.sessions_recorded}</div>
                        </div>
                        <div class="stat">
                            <div class="stat-label">Test</div>
                            <div>${game.test_status}</div>
                        </div>
                    </div>

                    <div class="game-links">
                        ${gameLinks}
                    </div>
                </div>
            `;
        }

        function applyFilters() {
            const title = document.getElementById('searchTitle').value.toLowerCase();
            const genre = document.getElementById('filterGenre').value;
            const difficulty = document.getElementById('filterDifficulty').value;
            const status = document.getElementById('filterStatus').value;
            const sort = document.getElementById('sortBy').value;

            let filtered = allGames.filter(game => {
                if (title && !game.title.toLowerCase().includes(title)) return false;
                if (genre && !(game.genres || []).includes(genre)) return false;
                if (difficulty && game.difficulty != difficulty) return false;
                if (status && game.completion_status !== status) return false;
                return true;
            });

            // Sort
            if (sort === 'date') {
                filtered.sort((a, b) => new Date(b.date) - new Date(a.date));
            } else if (sort === 'date-old') {
                filtered.sort((a, b) => new Date(a.date) - new Date(b.date));
            } else if (sort === 'title') {
                filtered.sort((a, b) => a.title.localeCompare(b.title));
            } else if (sort === 'difficulty') {
                filtered.sort((a, b) => b.difficulty - a.difficulty);
            } else if (sort === 'completion') {
                filtered.sort((a, b) => b.completion_rate - a.completion_rate);
            } else if (sort === 'sessions') {
                filtered.sort((a, b) => b.sessions_recorded - a.sessions_recorded);
            }

            // Render
            const gamesList = document.getElementById('gamesList');
            if (filtered.length === 0) {
                gamesList.innerHTML = '<div class="empty-state">No games match your filters</div>';
            } else {
                gamesList.innerHTML = filtered.map(renderGameCard).join('');
            }

            // Update summary
            const stats = {total: allGames.length, filtered: filtered.length};
            stats.sessions = filtered.reduce((sum, g) => sum + (g.sessions_recorded || 0), 0);
            const completionRates = filtered.filter(g => g.completion_rate > 0).map(g => g.completion_rate);
            stats.completion = completionRates.length > 0
                ? (completionRates.reduce((a, b) => a + b) / completionRates.length * 100).toFixed(0) + '%'
                : '-';

            document.getElementById('summaryTotal').textContent = stats.total;
            document.getElementById('summaryFiltered').textContent = stats.filtered;
            document.getElementById('summarySessions').textContent = stats.sessions;
            document.getElementById('summaryCompletion').textContent = stats.completion;
            document.getElementById('summary').style.display = 'grid';
        }

        function clearFilters() {
            document.getElementById('searchTitle').value = '';
            document.getElementById('filterGenre').value = '';
            document.getElementById('filterDifficulty').value = '';
            document.getElementById('filterStatus').value = '';
            document.getElementById('sortBy').value = 'date';
            applyFilters();
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        // Load games on page load
        loadGames();
    </script>
</body>
</html>
'''


def generate_stats_html():
    """Generate the statistics dashboard HTML page."""
    return '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Game Library Statistics</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
        }

        header {
            background: rgba(255, 255, 255, 0.95);
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        header h1 {
            color: #667eea;
        }

        .back-button {
            background: #f0f0f0;
            padding: 10px 20px;
            border-radius: 4px;
            text-decoration: none;
            color: #333;
            font-weight: 600;
            transition: background 0.3s;
        }

        .back-button:hover {
            background: #e0e0e0;
        }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .stat-box {
            background: rgba(255, 255, 255, 0.95);
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        }

        .stat-label {
            color: #999;
            font-size: 12px;
            margin-bottom: 10px;
            font-weight: 600;
        }

        .stat-value {
            font-size: 32px;
            font-weight: bold;
            color: #667eea;
            margin-bottom: 10px;
        }

        .stat-detail {
            font-size: 12px;
            color: #666;
        }

        .chart-container {
            background: rgba(255, 255, 255, 0.95);
            padding: 25px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        }

        .chart-container h2 {
            color: #333;
            margin-bottom: 20px;
            font-size: 16px;
        }

        .chart-wrapper {
            position: relative;
            height: 300px;
        }

        .footer {
            text-align: center;
            color: rgba(255, 255, 255, 0.8);
            font-size: 12px;
            margin-top: 40px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📊 Statistics Dashboard</h1>
            <a href="/" class="back-button">← Back to Library</a>
        </header>

        <div class="stats-grid">
            <div class="stat-box">
                <div class="stat-label">Total Games</div>
                <div class="stat-value" id="totalGames">-</div>
                <div class="stat-detail" id="totalGamesDetail">Loading...</div>
            </div>
            <div class="stat-box">
                <div class="stat-label">Total Sessions</div>
                <div class="stat-value" id="totalSessions">-</div>
                <div class="stat-detail">Recorded & analyzed</div>
            </div>
            <div class="stat-box">
                <div class="stat-label">Avg Completion Rate</div>
                <div class="stat-value" id="avgCompletion">-</div>
                <div class="stat-detail">Across all games</div>
            </div>
            <div class="stat-box">
                <div class="stat-label">Average Playtime</div>
                <div class="stat-value" id="avgPlaytime">-</div>
                <div class="stat-detail" id="playtimeRange">Loading...</div>
            </div>
        </div>

        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 20px;">
            <div class="chart-container">
                <h2>Genre Distribution</h2>
                <div class="chart-wrapper">
                    <canvas id="genreChart"></canvas>
                </div>
            </div>

            <div class="chart-container">
                <h2>Completion Status</h2>
                <div class="chart-wrapper">
                    <canvas id="statusChart"></canvas>
                </div>
            </div>

            <div class="chart-container">
                <h2>Difficulty Distribution</h2>
                <div class="chart-wrapper">
                    <canvas id="difficultyChart"></canvas>
                </div>
            </div>

            <div class="chart-container">
                <h2>Playtime Range</h2>
                <div class="chart-wrapper">
                    <canvas id="playtimeChart"></canvas>
                </div>
            </div>
        </div>

        <div class="footer">
            Statistics Dashboard v1.0
        </div>
    </div>

    <script>
        async function loadStatistics() {
            try {
                const response = await fetch('/api/catalog');
                const data = await response.json();
                const stats = data.statistics || {};

                // Update stat boxes
                document.getElementById('totalGames').textContent = data.total || 0;
                document.getElementById('totalGamesDetail').textContent = `${data.games ? data.games.length : 0} available`;
                document.getElementById('totalSessions').textContent = stats.total_sessions_recorded || 0;
                document.getElementById('avgCompletion').textContent = ((stats.average_completion_rate || 0) * 100).toFixed(0) + '%';

                if (stats.playtime_stats) {
                    document.getElementById('avgPlaytime').textContent = stats.playtime_stats.average + 'm';
                    document.getElementById('playtimeRange').textContent = `${stats.playtime_stats.min}-${stats.playtime_stats.max} minutes`;
                }

                // Genre chart
                if (stats.genre_distribution) {
                    const genres = Object.keys(stats.genre_distribution);
                    const counts = Object.values(stats.genre_distribution);

                    new Chart(document.getElementById('genreChart'), {
                        type: 'doughnut',
                        data: {
                            labels: genres.map(g => g.charAt(0).toUpperCase() + g.slice(1)),
                            datasets: [{
                                data: counts,
                                backgroundColor: [
                                    '#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF',
                                    '#FF9F40', '#FF6384', '#C9CBCF', '#4BC0C0', '#FF6384'
                                ]
                            }]
                        },
                        options: {
                            responsive: true,
                            maintainAspectRatio: false,
                            plugins: {
                                legend: {
                                    position: 'bottom'
                                }
                            }
                        }
                    });
                }

                // Status chart
                if (stats.completion_status_breakdown) {
                    const statuses = Object.keys(stats.completion_status_breakdown);
                    const counts = Object.values(stats.completion_status_breakdown);

                    new Chart(document.getElementById('statusChart'), {
                        type: 'doughnut',
                        data: {
                            labels: statuses.map(s => s.charAt(0).toUpperCase() + s.slice(1).replace('-', ' ')),
                            datasets: [{
                                data: counts,
                                backgroundColor: ['#FF6384', '#36A2EB', '#FFCE56']
                            }]
                        },
                        options: {
                            responsive: true,
                            maintainAspectRatio: false,
                            plugins: {
                                legend: {
                                    position: 'bottom'
                                }
                            }
                        }
                    });
                }

                // Difficulty distribution
                if (data.games) {
                    const diffCounts = [0, 0, 0, 0, 0];
                    data.games.forEach(game => {
                        const diff = (game.difficulty || 3) - 1;
                        if (diff >= 0 && diff < 5) diffCounts[diff]++;
                    });

                    new Chart(document.getElementById('difficultyChart'), {
                        type: 'bar',
                        data: {
                            labels: ['⭐', '⭐⭐', '⭐⭐⭐', '⭐⭐⭐⭐', '⭐⭐⭐⭐⭐'],
                            datasets: [{
                                label: 'Games',
                                data: diffCounts,
                                backgroundColor: '#667eea'
                            }]
                        },
                        options: {
                            responsive: true,
                            maintainAspectRatio: false,
                            plugins: {
                                legend: {
                                    display: false
                                }
                            },
                            scales: {
                                y: {
                                    beginAtZero: true
                                }
                            }
                        }
                    });
                }

                // Playtime distribution
                if (stats.playtime_stats) {
                    const pt = stats.playtime_stats;
                    new Chart(document.getElementById('playtimeChart'), {
                        type: 'bar',
                        data: {
                            labels: ['Min', 'Avg', 'Median', 'Max'],
                            datasets: [{
                                label: 'Minutes',
                                data: [pt.min, Math.round(pt.average), pt.median, pt.max],
                                backgroundColor: '#667eea'
                            }]
                        },
                        options: {
                            responsive: true,
                            maintainAspectRatio: false,
                            plugins: {
                                legend: {
                                    display: false
                                }
                            },
                            scales: {
                                y: {
                                    beginAtZero: true
                                }
                            }
                        }
                    });
                }
            } catch (error) {
                console.error('Error loading statistics:', error);
            }
        }

        loadStatistics();
    </script>
</body>
</html>
'''


def find_available_port(start_port=8000, max_port=8100):
    """Find an available port."""
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
    """Main entry point."""
    port = 8000

    # Parse command line arguments
    for arg in sys.argv[1:]:
        if arg.startswith('--port='):
            try:
                port = int(arg.split('=')[1])
            except ValueError:
                print(f"Invalid port: {arg}", file=sys.stderr)
                return 1
        elif arg == '--port' and len(sys.argv) > sys.argv.index(arg) + 1:
            try:
                port = int(sys.argv[sys.argv.index(arg) + 1])
            except ValueError:
                print(f"Invalid port: {sys.argv[sys.argv.index(arg) + 1]}", file=sys.stderr)
                return 1

    # Try to find an available port
    available_port = find_available_port(port)
    if available_port is None:
        print(f"Error: No available ports starting from {port}", file=sys.stderr)
        return 1

    port = available_port

    try:
        server_address = ('127.0.0.1', port)
        httpd = HTTPServer(server_address, GameLibraryHandler)
        print(f"🎮 Game Library server running at http://127.0.0.1:{port}", flush=True)
        print(f"   - Browser: http://127.0.0.1:{port}/", flush=True)
        print(f"   - Stats:   http://127.0.0.1:{port}/stats", flush=True)
        print(f"   - API:     http://127.0.0.1:{port}/api/catalog", flush=True)
        httpd.serve_forever()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n✓ Server stopped", flush=True)
        sys.exit(0)
