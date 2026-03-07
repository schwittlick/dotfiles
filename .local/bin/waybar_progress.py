#!/usr/bin/env python3
"""
waybar_progress.py — run this on marstation as a waybar custom module

Polls lyrik.local:9876 every few seconds, renders progress bars,
sends desktop notifications when jobs finish.

Waybar config:
    "custom/lyrik-progress": {
        "exec": "/path/to/waybar_progress.py",
        "return-type": "json",
        "interval": 5,
        "on-click": "/path/to/waybar_progress.py --clear-done"
    }
"""

import argparse
import json
import math
import socket
import subprocess
import sys
import time
from pathlib import Path

HOST = "lyrik.local"
PORT = 9876
STATE_FILE = Path.home() / ".cache" / "waybar_progress_notified.json"

BAR_WIDTH = 12  # characters for the progress bar


def query_jobs() -> list[dict] | None:
    try:
        with socket.create_connection((HOST, PORT), timeout=3) as s:
            s.sendall(json.dumps({"type": "query"}) + b"\n"
                      if isinstance(json.dumps({"type": "query"}), bytes)
                      else (json.dumps({"type": "query"}) + "\n").encode())
            data = b""
            while True:
                chunk = s.recv(4096)
                if not chunk:
                    break
                data += chunk
        return json.loads(data.decode())["jobs"]
    except Exception:
        return None


def send_command(msg: dict):
    try:
        with socket.create_connection((HOST, PORT), timeout=3) as s:
            s.sendall((json.dumps(msg) + "\n").encode())
    except Exception:
        pass


def render_bar(progress: float, width: int = BAR_WIDTH) -> str:
    """Render a unicode block progress bar."""
    filled = progress * width
    full_blocks = int(filled)
    partial = filled - full_blocks

    # 8 partial block chars: ▏▎▍▌▋▊▉█
    partials = " ▏▎▍▌▋▊▉█"
    partial_char = partials[math.floor(partial * 8)]

    bar = "█" * full_blocks
    if full_blocks < width:
        bar += partial_char
        bar += " " * (width - full_blocks - 1)

    return f"[{bar}]"


def load_notified() -> set:
    try:
        return set(json.loads(STATE_FILE.read_text()))
    except Exception:
        return set()


def save_notified(ids: set):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(list(ids)))


def notify(job: dict):
    label = job.get("label", job["id"])
    try:
        subprocess.Popen([
            "notify-send",
            "--app-name=lyrik",
            "--icon=system-run",
            f"Job finished: {label}",
            f"Job ID: {job['id']}\nProgress: 100%",
        ])
    except FileNotFoundError:
        pass  # notify-send not available


def format_duration(seconds: float | None) -> str:
    if seconds is None:
        return "?"
    seconds = int(seconds)
    h, m, s = seconds // 3600, (seconds % 3600) // 60, seconds % 60
    if h:
        return f"{h}h{m:02d}m"
    if m:
        return f"{m}m{s:02d}s"
    return f"{s}s"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--clear-done", action="store_true",
                        help="Clear all finished jobs and exit")
    args = parser.parse_args()

    if args.clear_done:
        send_command({"type": "clear_done"})
        # also clear local notification state for finished jobs
        save_notified(set())
        sys.exit(0)

    jobs = query_jobs()

    if jobs is None:
        # server unreachable
        print(json.dumps({
            "text": "⚠ lyrik offline",
            "tooltip": "Cannot reach lyrik.local:9876",
            "class": "offline",
        }))
        sys.exit(0)

    if not jobs:
        print(json.dumps({
            "text": "",
            "tooltip": "No jobs running on lyrik",
            "class": "idle",
        }))
        sys.exit(0)

    notified = load_notified()
    now = time.time()

    # send notifications for newly finished jobs
    for job in jobs:
        jid = job["id"]
        if job.get("done") and jid not in notified:
            notify(job)
            notified.add(jid)
    save_notified(notified)

    # build display
    running = [j for j in jobs if not j.get("done")]
    done = [j for j in jobs if j.get("done")]

    # short text: counts + mini bars for running jobs
    if running:
        mini_bars = []
        for j in running:
            pct = int(j["progress"] * 100)
            mini_bars.append(f"{j['label'][:10]} {pct}%")
        text = "  ".join(mini_bars)
        if done:
            text += f"  ✓{len(done)}"
    else:
        text = f"✓ {len(done)} done — click to clear"

    # tooltip: full detail for all jobs
    tooltip_lines = []

    if running:
        tooltip_lines.append("── Running ──")
        for j in running:
            bar = render_bar(j["progress"])
            pct = j["progress"] * 100
            elapsed = format_duration(now - j["started"]) if j.get("started") else "?"
            tooltip_lines.append(f"{j['label']}")
            tooltip_lines.append(f"  {bar} {pct:5.1f}%  elapsed: {elapsed}")
            tooltip_lines.append(f"  id: {j['id']}")

    if done:
        if running:
            tooltip_lines.append("")
        tooltip_lines.append("── Finished ──")
        for j in done:
            bar = render_bar(1.0)
            elapsed = ""
            if j.get("started") and j.get("finished"):
                elapsed = f"  took: {format_duration(j['finished'] - j['started'])}"
            tooltip_lines.append(f"{j['label']}")
            tooltip_lines.append(f"  {bar} 100%{elapsed}")
            tooltip_lines.append(f"  id: {j['id']}")

    tooltip_lines.append("")
    tooltip_lines.append("Click to clear finished jobs")

    css_class = "done" if not running else "running"

    print(json.dumps({
        "text": text,
        "tooltip": "\n".join(tooltip_lines),
        "class": css_class,
    }))


if __name__ == "__main__":
    main()
