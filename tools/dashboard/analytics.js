/**
 * Analytics Dashboard - Client-side interactivity
 */

let analyticsData = null;
let gamesList = null;

/**
 * Initialize dashboard on page load
 */
document.addEventListener('DOMContentLoaded', function() {
    loadAnalytics();
});

/**
 * Load master analytics report from API
 */
async function loadAnalytics() {
    try {
        const response = await fetch('/api/analytics');
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        analyticsData = await response.json();
        loadGamesList();
        updateHeaderStats();
        updateComparisons();
    } catch (error) {
        console.error('Failed to load analytics:', error);
        document.getElementById('gamesLoading').innerHTML =
            `<div class="error">Failed to load analytics: ${error.message}</div>`;
    }
}

/**
 * Load games list from API
 */
async function loadGamesList() {
    try {
        const response = await fetch('/api/games');
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        gamesList = await response.json();
        renderGamesList();
    } catch (error) {
        console.error('Failed to load games:', error);
    }
}

/**
 * Update header statistics
 */
function updateHeaderStats() {
    if (!analyticsData) return;

    const crossGame = analyticsData.cross_game_metrics || {};
    const perGame = analyticsData.per_game_summaries || {};

    document.getElementById('totalGames').textContent = analyticsData.total_games || 0;
    document.getElementById('gamesWithSessions').textContent = crossGame.games_with_sessions || 0;

    const avgCompletion = crossGame.avg_completion_rate || 0;
    document.getElementById('avgCompletion').textContent = avgCompletion.toFixed(1) + '%';

    const avgDuration = crossGame.avg_session_duration || 0;
    document.getElementById('avgDuration').textContent = Math.round(avgDuration) + ' frames';
}

/**
 * Render games list from API data
 */
function renderGamesList() {
    const container = document.getElementById('gamesList');
    const loadingEl = document.getElementById('gamesLoading');

    if (!gamesList || !gamesList.games) {
        loadingEl.innerHTML = '<div class="error">No games found</div>';
        return;
    }

    const games = gamesList.games;
    if (games.length === 0) {
        loadingEl.innerHTML = '<div class="error">No games found</div>';
        return;
    }

    let html = '';
    for (const game of games) {
        const perGameData = analyticsData.per_game_summaries?.[game.date] || {};
        const metrics = perGameData.metrics || {};

        let statusClass = 'status-no-data';
        let statusText = 'No Data';

        if (perGameData.test_status === 'PASS') {
            statusClass = 'status-pass';
            statusText = '✓ Pass';
        } else if (perGameData.test_status === 'FAIL') {
            statusClass = 'status-fail';
            statusText = '✗ Fail';
        }

        const completionRate = metrics.completion_rate_pct || 0;
        const avgDuration = metrics.avg_duration_frames || 0;
        const sessionCount = game.session_count || 0;

        html += `
            <div class="game-card" onclick="openGameModal('${game.date}')">
                <div class="status-badge ${statusClass}">${statusText}</div>
                <div class="game-date">${game.date}</div>
                <div class="game-stats">
                    <div class="game-stat">
                        <span class="game-stat-label">Sessions</span>
                        <span class="game-stat-value">${sessionCount}</span>
                    </div>
                    <div class="game-stat">
                        <span class="game-stat-label">Completion</span>
                        <span class="game-stat-value">${completionRate.toFixed(1)}%</span>
                    </div>
                    <div class="game-stat">
                        <span class="game-stat-label">Avg Duration</span>
                        <span class="game-stat-value">${Math.round(avgDuration)}</span>
                    </div>
                    <div class="game-stat">
                        <span class="game-stat-label">Difficulty Cliff</span>
                        <span class="game-stat-value">${metrics.difficulty_cliff_frame || '—'}</span>
                    </div>
                </div>
            </div>
        `;
    }

    container.innerHTML = html;
    container.style.display = 'grid';
    loadingEl.style.display = 'none';
}

/**
 * Update comparison tables
 */
function updateComparisons() {
    if (!analyticsData) return;

    const crossGame = analyticsData.cross_game_metrics || {};

    // Completion rate ranking
    const completionRanking = crossGame.completion_rate_ranking || [];
    let completionHtml = '';

    for (let i = 0; i < completionRanking.length; i++) {
        const [date, rate] = completionRanking[i];
        const perGameData = analyticsData.per_game_summaries?.[date] || {};
        const sessionCount = perGameData.session_count || 0;

        completionHtml += `
            <tr onclick="openGameModal('${date}')" style="cursor: pointer;">
                <td class="rank">${i + 1}</td>
                <td>${date}</td>
                <td><strong>${rate.toFixed(1)}%</strong></td>
                <td>${sessionCount}</td>
            </tr>
        `;
    }

    if (completionHtml === '') {
        completionHtml = '<tr><td colspan="4" style="text-align: center; color: #999;">No session data available</td></tr>';
    }

    document.getElementById('completionBody').innerHTML = completionHtml;

    // Duration ranking
    const durationRanking = crossGame.duration_ranking || [];
    let durationHtml = '';

    for (let i = 0; i < durationRanking.length; i++) {
        const [date, duration] = durationRanking[i];
        const perGameData = analyticsData.per_game_summaries?.[date] || {};
        const sessionCount = perGameData.session_count || 0;

        durationHtml += `
            <tr onclick="openGameModal('${date}')" style="cursor: pointer;">
                <td class="rank">${i + 1}</td>
                <td>${date}</td>
                <td><strong>${Math.round(duration)} frames</strong></td>
                <td>${sessionCount}</td>
            </tr>
        `;
    }

    if (durationHtml === '') {
        durationHtml = '<tr><td colspan="4" style="text-align: center; color: #999;">No session data available</td></tr>';
    }

    document.getElementById('durationBody').innerHTML = durationHtml;
}

/**
 * Open game detail modal
 */
async function openGameModal(date) {
    const perGameData = analyticsData.per_game_summaries?.[date];
    if (!perGameData) return;

    const metrics = perGameData.metrics || {};
    const testStatus = perGameData.test_status || 'Unknown';

    // Build modal content
    let content = `
        <div class="stat-card">
            <div class="stat-label">Test Status</div>
            <div class="stat-value">${testStatus}</div>
        </div>
    `;

    if (perGameData.has_sessions && Object.keys(metrics).length > 0) {
        content += `
            <div style="margin-top: 20px;">
                <h3 style="font-size: 16px; margin-bottom: 15px;">Metrics</h3>
                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-label">Completion Rate</div>
                        <div class="stat-value">${(metrics.completion_rate_pct || 0).toFixed(1)}%</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-label">Avg Duration</div>
                        <div class="stat-value">${Math.round(metrics.avg_duration_frames || 0)}</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-label">Median Duration</div>
                        <div class="stat-value">${Math.round(metrics.median_duration_frames || 0)}</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-label">Difficulty Cliff</div>
                        <div class="stat-value">${metrics.difficulty_cliff_frame || '—'}</div>
                    </div>
                </div>
            </div>
        `;

        // Completion breakdown
        const breakdown = metrics.completion_breakdown || {};
        if (Object.keys(breakdown).length > 0) {
            content += `
                <div style="margin-top: 20px;">
                    <h3 style="font-size: 16px; margin-bottom: 10px;">Completion Breakdown</h3>
                    <table class="comparison-table">
                        <tbody>
            `;

            for (const [status, count] of Object.entries(breakdown)) {
                const percentage = perGameData.session_count > 0 ?
                    (count / perGameData.session_count * 100).toFixed(1) : 0;
                content += `
                    <tr>
                        <td style="font-weight: bold;">${status}</td>
                        <td>${count} sessions (${percentage}%)</td>
                    </tr>
                `;
            }

            content += `
                        </tbody>
                    </table>
                </div>
            `;
        }

        // State times
        const stateTimes = metrics.avg_state_times || {};
        if (Object.keys(stateTimes).length > 0) {
            content += `
                <div style="margin-top: 20px;">
                    <h3 style="font-size: 16px; margin-bottom: 10px;">Time per State (avg frames)</h3>
                    <table class="comparison-table">
                        <tbody>
            `;

            for (const [state, time] of Object.entries(stateTimes)) {
                content += `
                    <tr>
                        <td style="font-weight: bold;">${state}</td>
                        <td>${time} frames</td>
                    </tr>
                `;
            }

            content += `
                        </tbody>
                    </table>
                </div>
            `;
        }
    } else {
        content += `
            <div style="margin-top: 20px; padding: 15px; background: #f0f0f0; border-radius: 4px; color: #666;">
                No session data recorded yet. Run the interactive test runner to record gameplay sessions.
            </div>
        `;
    }

    document.getElementById('modalGameDate').textContent = `Game: ${date}`;
    document.getElementById('modalContent').innerHTML = content;

    const modal = document.getElementById('gameModal');
    modal.classList.add('active');
}

/**
 * Close game detail modal
 */
function closeGameModal(event) {
    // Only close if clicking on modal background or X button
    if (event && event.target.id !== 'gameModal') return;

    const modal = document.getElementById('gameModal');
    modal.classList.remove('active');
}

/**
 * Switch between tabs
 */
function switchTab(tabName) {
    // Hide all tab contents
    const contents = document.querySelectorAll('.tab-content');
    contents.forEach(el => el.classList.remove('active'));

    // Deactivate all tabs
    const tabs = document.querySelectorAll('.tab');
    tabs.forEach(el => el.classList.remove('active'));

    // Show selected tab content
    const selectedContent = document.getElementById(tabName);
    if (selectedContent) {
        selectedContent.classList.add('active');
    }

    // Activate clicked tab
    event.target.classList.add('active');
}

/**
 * Format large numbers with commas
 */
function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}
