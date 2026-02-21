#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y python3-pip

mkdir -p /opt/app/templates

cat <<'EOF' > /opt/app/app.py
import os
import time
from flask import Flask, jsonify, render_template

app = Flask(__name__)
START_TIME = time.time()


@app.get("/")
def index():
    return render_template("index.html")


@app.get("/health")
def health():
    return jsonify({"status": "ok"}), 200


@app.get("/api/status")
def api_status():
    uptime_seconds = int(time.time() - START_TIME)
    return jsonify({"status": "healthy", "uptime": uptime_seconds})


@app.post("/crash")
def crash():
    os._exit(1)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

cat <<'EOF' > /opt/app/templates/index.html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Auto-Healing Infrastructure Dashboard</title>
  <style>
    :root {
      --bg: #0b1020;
      --bg-panel: #111a33;
      --text: #dbe4ff;
      --muted: #9aa8d9;
      --healthy: #18c964;
      --unhealthy: #ff4d4f;
      --accent: #3a7bff;
      --danger: #d7263d;
      --danger-hover: #b71f32;
      --border: #1f2b4d;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      min-height: 100vh;
      font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
      background: radial-gradient(circle at top right, #162b56 0%, var(--bg) 45%);
      color: var(--text);
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }

    .card {
      width: 100%;
      max-width: 760px;
      background: linear-gradient(180deg, rgba(17, 26, 51, 0.95) 0%, rgba(12, 18, 36, 0.98) 100%);
      border: 1px solid var(--border);
      border-radius: 16px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.35);
      padding: 28px;
    }

    h1 {
      margin: 0 0 8px;
      font-size: clamp(1.4rem, 2.8vw, 2rem);
      letter-spacing: 0.5px;
    }

    .subtitle {
      margin: 0 0 24px;
      color: var(--muted);
    }

    .status-wrap {
      display: flex;
      gap: 14px;
      align-items: center;
      flex-wrap: wrap;
      margin-bottom: 20px;
    }

    .badge {
      font-size: 1.1rem;
      font-weight: 700;
      padding: 12px 20px;
      border-radius: 999px;
      letter-spacing: 0.4px;
      text-transform: uppercase;
    }

    .healthy {
      background: rgba(24, 201, 100, 0.15);
      color: var(--healthy);
      border: 1px solid rgba(24, 201, 100, 0.45);
    }

    .unhealthy {
      background: rgba(255, 77, 79, 0.12);
      color: var(--unhealthy);
      border: 1px solid rgba(255, 77, 79, 0.5);
    }

    .stats {
      display: grid;
      grid-template-columns: repeat(2, minmax(180px, 1fr));
      gap: 12px;
      margin-bottom: 24px;
    }

    .stat {
      background: rgba(58, 123, 255, 0.08);
      border: 1px solid rgba(58, 123, 255, 0.22);
      border-radius: 12px;
      padding: 14px;
    }

    .stat-label {
      font-size: 0.88rem;
      color: var(--muted);
      margin-bottom: 6px;
    }

    .stat-value {
      font-size: 1.35rem;
      font-weight: 700;
    }

    .message {
      min-height: 24px;
      color: #c8d4ff;
      margin-bottom: 18px;
    }

    .danger-btn {
      width: 100%;
      border: 0;
      border-radius: 12px;
      padding: 16px 18px;
      color: white;
      background: var(--danger);
      font-size: 1rem;
      font-weight: 700;
      cursor: pointer;
      transition: transform 0.15s ease, background 0.2s ease;
    }

    .danger-btn:hover {
      background: var(--danger-hover);
      transform: translateY(-1px);
    }

    .danger-btn:disabled {
      opacity: 0.6;
      cursor: not-allowed;
      transform: none;
    }

    @media (max-width: 640px) {
      .card {
        padding: 20px;
      }

      .stats {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>
  <main class="card">
    <h1>Auto-Healing Infrastructure</h1>
    <p class="subtitle">Live node health and uptime monitoring (GCP MIG auto-healing demo)</p>

    <section class="status-wrap">
      <span id="statusBadge" class="badge healthy">Healthy</span>
    </section>

    <section class="stats">
      <div class="stat">
        <div class="stat-label">Application Status</div>
        <div id="statusText" class="stat-value">healthy</div>
      </div>
      <div class="stat">
        <div class="stat-label">Uptime (seconds)</div>
        <div id="uptime" class="stat-value">0</div>
      </div>
    </section>

    <div id="message" class="message">System operating normally.</div>

    <button id="crashBtn" class="danger-btn">SIMULATE CRASH</button>
  </main>

  <script>
    const statusBadge = document.getElementById("statusBadge");
    const statusText = document.getElementById("statusText");
    const uptimeEl = document.getElementById("uptime");
    const messageEl = document.getElementById("message");
    const crashBtn = document.getElementById("crashBtn");

    function setHealthy(uptime) {
      statusBadge.textContent = "Healthy";
      statusBadge.classList.remove("unhealthy");
      statusBadge.classList.add("healthy");
      statusText.textContent = "healthy";
      uptimeEl.textContent = Number.isFinite(uptime) ? uptime : 0;
      messageEl.textContent = "System operating normally.";
      crashBtn.disabled = false;
    }

    function setUnhealthy(text) {
      statusBadge.textContent = "Unhealthy";
      statusBadge.classList.remove("healthy");
      statusBadge.classList.add("unhealthy");
      statusText.textContent = "connection_lost";
      messageEl.textContent = text || "Connection Lost. Waiting for auto-healing...";
    }

    async function pollStatus() {
      try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 1200);

        const response = await fetch("/api/status", { signal: controller.signal });
        clearTimeout(timeout);

        if (!response.ok) {
          throw new Error("Non-200 response from status API");
        }

        const data = await response.json();
        const uptime = Number.parseInt(data.uptime, 10);
        setHealthy(uptime);
      } catch (error) {
        setUnhealthy("Connection Lost. Waiting for auto-healing and instance replacement...");
      }
    }

    crashBtn.addEventListener("click", async () => {
      crashBtn.disabled = true;
      messageEl.textContent = "Crashing instance...";

      try {
        await fetch("/crash", { method: "POST" });
      } catch (error) {
      }

      setUnhealthy("Crash triggered. Waiting for MIG auto-healing...");
    });

    pollStatus();
    setInterval(pollStatus, 1000);
  </script>
</body>
</html>
EOF

pip3 install flask

cat <<'EOF' > /etc/systemd/system/autoheal-app.service
[Unit]
Description=Auto-Healing Flask App
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/app
ExecStart=/usr/bin/python3 /opt/app/app.py
Restart=always
RestartSec=1
StandardOutput=append:/var/log/app.log
StandardError=append:/var/log/app.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now autoheal-app.service
