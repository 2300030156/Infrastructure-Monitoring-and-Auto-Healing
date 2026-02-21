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
