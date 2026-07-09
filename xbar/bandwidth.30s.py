#!/usr/bin/env python3
# <xbar.title>Bandwidth</xbar.title>
# <xbar.version>v3.1</xbar.version>
# <xbar.author>Kiba Labs</xbar.author>
# <xbar.author.github>kibalabs</xbar.author.github>
# <xbar.dependencies>python3</xbar.dependencies>
#
# Fixed-width menu bar icon: two thin bars (down, up), log-scaled so both
# a trickle and a saturated link register visibly. Replaces a
# "▼ NNN(B|KB|MB|GB)/s ▲ ..." label whose width jumped around on every
# sample as units/digit-counts changed. Exact rates are one click away.
#
# Deliberately live-rate-only, no per-process breakdown: a `nettop`-based
# "what's using bandwidth" section was tried and dropped — even a 1s sample
# cost ~1.5s of CPU per run (nettop's own kernel-side accounting, not
# Python), and there's no cheaper way to get useful per-process coverage
# (sub-second windows mostly miss everything but the chattiest process).
# Not worth it for a menu bar widget; interface-level rate is nearly free.

import base64
import json
import math
import os
import struct
import subprocess
import time
import zlib

INTERFACE = "en0"
STATE_FILE = f"/tmp/swiftbar_bandwidth_{INTERFACE}.json"
LOG_CAP = 5 * 1024 * 1024  # 5 MB/s reads as a "full" bar; well past it just clips at 100%

# ---- icon rendering ----

def is_dark_menu_bar():
    """SwiftBar exports OS_APPEARANCE; fall back to the global default."""
    appearance = os.environ.get("OS_APPEARANCE")
    if appearance:
        return appearance.lower() == "dark"
    try:
        out = subprocess.run(
            ["defaults", "read", "-g", "AppleInterfaceStyle"],
            capture_output=True, text=True, timeout=10,
        )
    except subprocess.TimeoutExpired:
        return True
    return out.returncode == 0 and "Dark" in out.stdout

def encode_png(width, height, pixels):
    raw = b"".join(
        b"\x00" + b"".join(struct.pack("4B", *px) for px in row)
        for row in pixels
    )

    def chunk(typ, data):
        body = typ + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    phys = struct.pack(">IIB", 5669, 5669, 1)  # 144 dpi -> renders at half size, crisp on retina
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"pHYs", phys)
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))

def fill_rect(pixels, x0, y0, x1, y1, color):
    h, w = len(pixels), len(pixels[0])
    for y in range(max(0, y0), min(h, y1)):
        for x in range(max(0, x0), min(w, x1)):
            pixels[y][x] = color

def draw_bar(pixels, x, y, width, height, color, pct):
    """One thin outlined bar; pct=None draws an empty outline (no data)."""
    t = 2
    fill_rect(pixels, x, y, x + width, y + t, color)
    fill_rect(pixels, x, y + height - t, x + width, y + height, color)
    fill_rect(pixels, x, y, x + t, y + height, color)
    fill_rect(pixels, x + width - t, y, x + width, y + height, color)
    if pct is None:
        return
    inner_h = height - 2 * t - 2
    fill_h = round(inner_h * min(100, max(0, pct)) / 100)
    if pct > 0 and fill_h == 0:
        fill_h = 1
    fill_rect(pixels, x + t + 1, y + height - t - 1 - fill_h,
              x + width - t - 1, y + height - t - 1, color)

DOWN_COLOR = (10, 132, 255, 255)  # fixed blue accent for download

def rate_to_pct(rate):
    if not rate or rate <= 0:
        return 0
    return max(0, min(100, 100 * math.log10(rate + 1) / math.log10(LOG_CAP + 1)))

def bandwidth_icon(in_rate, out_rate):
    fg = (255, 255, 255, 255) if is_dark_menu_bar() else (0, 0, 0, 255)
    bar_w, bar_h, gap = 8, 24, 4
    width, height = bar_w * 2 + gap, 32
    pixels = [[(0, 0, 0, 0)] * width for _ in range(height)]
    y = (height - bar_h) // 2
    draw_bar(pixels, 0, y, bar_w, bar_h, DOWN_COLOR, rate_to_pct(in_rate))
    draw_bar(pixels, bar_w + gap, y, bar_w, bar_h, fg, rate_to_pct(out_rate))
    return base64.b64encode(encode_png(width, height, pixels)).decode()

# ---- interface-level rate (down/up summary + icon fill) ----

def format_rate(bytes_per_sec):
    if not bytes_per_sec and bytes_per_sec != 0:
        return "--"
    b = bytes_per_sec
    if b < 1024:
        return f"{b:.0f}B/s"
    if b < 1024 ** 2:
        return f"{b / 1024:.0f}KB/s"
    if b < 1024 ** 3:
        return f"{b / 1024 ** 2:.0f}MB/s"
    return f"{b / 1024 ** 3:.0f}GB/s"

def read_counters():
    """Return (in_bytes, out_bytes) for INTERFACE, or (None, None)."""
    out = subprocess.run(["netstat", "-ib"], capture_output=True, text=True, timeout=10)
    for line in out.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 10 and parts[0] == INTERFACE and "Link" in parts[2]:
            return int(parts[6]), int(parts[9])
    return None, None

def interface_rates():
    now = time.time()
    in_bytes, out_bytes = read_counters()

    in_rate = out_rate = None
    try:
        with open(STATE_FILE) as f:
            prev = json.load(f)
        dt = now - prev["t"]
        if dt > 0 and in_bytes is not None:
            in_rate = max(0, (in_bytes - prev["in"]) / dt)
            out_rate = max(0, (out_bytes - prev["out"]) / dt)
    except (OSError, json.JSONDecodeError, KeyError, TypeError):
        pass

    if in_bytes is not None:
        try:
            with open(STATE_FILE, "w") as f:
                json.dump({"t": now, "in": in_bytes, "out": out_bytes}, f)
        except OSError:
            pass
    return in_rate, out_rate

def main():
    in_rate, out_rate = interface_rates()

    try:
        print(f"| image={bandwidth_icon(in_rate, out_rate)}")
    except Exception:
        print(f"▼ {format_rate(in_rate)} ▲ {format_rate(out_rate)}")
    print("---")
    print(f"↓ {format_rate(in_rate)}   ↑ {format_rate(out_rate)} | font=Menlo")
    print("---")
    print("Open Activity Monitor | bash=open param1=-a param2='Activity Monitor' terminal=false refresh=false")
    print("---")
    print("Refresh | refresh=true")

if __name__ == "__main__":
    main()
