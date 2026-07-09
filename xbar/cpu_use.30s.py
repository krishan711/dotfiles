#!/usr/bin/env python3
# <xbar.title>CPU Use</xbar.title>
# <xbar.version>v3.1</xbar.version>
# <xbar.author>Kiba Labs</xbar.author>
# <xbar.author.github>kibalabs</xbar.author.github>
# <xbar.dependencies>python3</xbar.dependencies>
#
# Fixed-width menu bar icon: one thin bar, fuller = busier. Replaces a
# "NN.N%" text label whose width (and therefore everything to its right)
# reflowed on every sample as the digit count changed. Color shifts
# green -> orange -> red as load climbs; exact percentage and the top
# processes right now are one click away in the dropdown.
#
# Live snapshot only, by design: macOS has no persistent per-process CPU
# history to query on demand, so a "last hour" view would mean faking one
# by sampling+accumulating ourselves — not real OS-level data, just an
# approximation. Not worth the complexity; this shows what `ps` reports
# right now, same as the bandwidth plugin's live-only view.

import base64
import os
import struct
import subprocess
import zlib

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

def load_color(pct):
    if pct >= 80:
        return (255, 59, 48, 255)   # red
    if pct >= 50:
        return (255, 159, 10, 255)  # orange
    return (52, 199, 89, 255)       # green

def cpu_icon(pct):
    bar_w, bar_h = 10, 24
    width, height = bar_w, 32
    pixels = [[(0, 0, 0, 0)] * width for _ in range(height)]
    y = (height - bar_h) // 2
    draw_bar(pixels, 0, y, bar_w, bar_h, load_color(pct), pct)
    return base64.b64encode(encode_png(width, height, pixels)).decode()

# ---- sampling ----

def sample_processes():
    """One `ps` call -> (total_pcpu, {name: summed_pcpu}) across ALL
    processes, aggregated by short name (ps's own ucomm field — a process
    that shows up as several PIDs under the same name, e.g. helper
    processes, is summed into one row)."""
    out = subprocess.run(["ps", "-Ao", "pcpu=,ucomm="], capture_output=True, text=True, timeout=10)
    procs, total = {}, 0.0
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        try:
            pcpu = float(parts[0])
        except ValueError:
            continue
        name = parts[1]
        total += pcpu
        procs[name] = procs.get(name, 0.0) + pcpu
    return total, procs

def main():
    ncpu = os.cpu_count() or 1
    try:
        total_pcpu, procs = sample_processes()
    except Exception:
        print("CPU ⚠")
        print("---")
        print("Refresh | refresh=true")
        return
    usage = total_pcpu / ncpu

    try:
        print(f"| image={cpu_icon(usage)}")
    except Exception:
        print(f"{usage:.1f}%")
    print("---")
    print(f"CPU: {usage:.1f}% | font=Menlo")

    print("---")
    print("What's using CPU")
    for name, pcpu in sorted(procs.items(), key=lambda kv: kv[1], reverse=True)[:8]:
        if pcpu < 0.1:
            continue
        print(f"{pcpu:>5.1f}%  {name} | font=Menlo")

    print("---")
    print("Open Activity Monitor | bash=open param1=-a param2='Activity Monitor' terminal=false refresh=false")
    print("---")
    print("Refresh | refresh=true")

if __name__ == "__main__":
    main()
