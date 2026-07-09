#!/usr/bin/env python3
# <xbar.title>AI Usage (Claude + Codex)</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Kiba Labs</xbar.author>
# <xbar.author.github>kibalabs</xbar.author.github>
# <xbar.desc>5-hour and weekly quota for Claude Code and Codex CLI, read via their own OAuth logins.</xbar.desc>
# <xbar.dependencies>python3</xbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
#
# Read-only: reuses whichever OAuth token `claude` / `codex` already logged
# in with and queries the same internal usage endpoints their own status
# screens use. Never refreshes or rewrites a token, so it can't log you out.
#
#   Claude Code -> macOS Keychain "Claude Code-credentials" by default
#                  (falls back to $CLAUDE_CONFIG_DIR/.credentials.json)
#                  -> GET https://api.anthropic.com/api/oauth/usage
#   Codex CLI   -> $CODEX_HOME/auth.json (default ~/.codex/auth.json)
#                  -> GET https://chatgpt.com/backend-api/wham/usage
#
# Both endpoints are undocumented/internal to their respective CLIs, so a
# future update may require a small fix here. Anthropic's usage endpoint
# rate-limits aggressively (see anthropics/claude-code#31637), so results
# are cached for a few minutes regardless of how often SwiftBar re-runs
# this script.
#
# Discreet storage (optional): if you'd rather these tokens not sit at the
# well-known default paths, point this script at wherever you actually put
# them via ~/.config/ai-usage-xbar/config.json (paths only, never secrets):
#   {
#     "claude_token_file": "/abs/path/to/a/file holding just the token text",
#     "codex_home": "/abs/path/to/a/relocated $CODEX_HOME"
#   }
# claude_token_file: paste the output of `claude setup-token` (a 1-year OAuth
#   token Claude Code itself never writes to disk — you choose where it
#   lives). Unverified whether its scope covers this usage endpoint; if it
#   401s, delete the pointer and this falls back to Keychain.
# codex_home: run `CODEX_HOME=/that/path codex login` once first — Codex CLI
#   fully supports relocating $CODEX_HOME, confirmed by OpenAI's own docs.
# Env vars AI_USAGE_CLAUDE_TOKEN_FILE / CODEX_HOME override the config file,
# for testing from a real shell (SwiftBar itself won't inherit shell rc env).

import base64
import hashlib
import json
import os
import struct
import subprocess
import time
import urllib.error
import urllib.request
import zlib
from datetime import datetime, timezone

CLAUDE_USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
CODEX_USAGE_URL = "https://chatgpt.com/backend-api/wham/usage"
CACHE_DIR = os.path.expanduser("~/.cache/ai-usage-xbar")
CACHE_TTL = 240  # seconds; keeps requests bounded no matter the refresh cadence

def load_pointer_config():
    """Paths only, never secrets: ~/.config/ai-usage-xbar/config.json."""
    path = os.path.expanduser("~/.config/ai-usage-xbar/config.json")
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}

POINTER_CONFIG = load_pointer_config()

# ---- credentials ----

def claude_config_dir():
    return os.path.expanduser(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude"))

def claude_keychain_service():
    # Matches Claude Code's own naming: the default ~/.claude config dir uses
    # a fixed service name; any other CLAUDE_CONFIG_DIR gets a hashed suffix.
    config_dir = claude_config_dir()
    if config_dir == os.path.expanduser("~/.claude"):
        return "Claude Code-credentials"
    digest = hashlib.sha256(config_dir.encode()).hexdigest()[:8]
    return f"Claude Code-credentials-{digest}"

def claude_token_file():
    return os.environ.get("AI_USAGE_CLAUDE_TOKEN_FILE") or POINTER_CONFIG.get("claude_token_file")

def get_claude_token():
    """Return (token, error)."""
    override = claude_token_file()
    if override:
        # Discreet path: a bare token (e.g. from `claude setup-token`) that
        # Claude Code itself never wrote to disk. No local expiry to check —
        # a rejected token surfaces as a 401 from the usage endpoint.
        try:
            with open(os.path.expanduser(override)) as f:
                token = f.read().strip()
        except OSError:
            return None, f"claude_token_file not readable: {override}"
        return (token, None) if token else (None, "claude_token_file is empty")
    raw = None
    try:
        out = subprocess.run(
            ["security", "find-generic-password", "-s", claude_keychain_service(), "-w"],
            capture_output=True, text=True, timeout=10,
        )
        if out.returncode == 0:
            raw = out.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    if raw is None:
        # No Keychain (Linux, or not yet granted access): fall back to the
        # plaintext credentials file Claude Code also writes.
        cred_path = os.path.join(claude_config_dir(), ".credentials.json")
        try:
            with open(cred_path) as f:
                raw = f.read()
        except OSError:
            return None, "not logged in — run `claude` once and /login"
    try:
        creds = json.loads(raw)["claudeAiOauth"]
    except (json.JSONDecodeError, KeyError, TypeError):
        return None, "unexpected credential format"
    expires_at = creds.get("expiresAt")
    if expires_at and expires_at / 1000 < time.time():
        return None, "token stale — run `claude` once to refresh"
    token = creds.get("accessToken")
    if not token:
        return None, "not logged in — run `claude` once and /login"
    return token, None

def get_codex_token():
    """Return (token, error)."""
    codex_home = os.path.expanduser(
        os.environ.get("CODEX_HOME") or POINTER_CONFIG.get("codex_home") or "~/.codex"
    )
    try:
        with open(os.path.join(codex_home, "auth.json")) as f:
            auth = json.load(f)
    except OSError:
        return None, "not logged in — run `codex login`"
    except json.JSONDecodeError:
        return None, "unexpected credential format"
    token = (auth.get("tokens") or {}).get("access_token")
    if not token:
        return None, "not logged in — run `codex login`"
    return token, None

# ---- fetching (cached) ----

def http_get_json(url, token):
    """Return (data, error, retry_after_seconds)."""
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    })
    if url == CLAUDE_USAGE_URL:
        req.add_header("anthropic-beta", "oauth-2025-04-20")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read()), None, None
    except urllib.error.HTTPError as e:
        if e.code == 401:
            return None, "token rejected — log in again", None
        if e.code == 429:
            try:
                retry = int(e.headers.get("Retry-After", ""))
            except (TypeError, ValueError):
                retry = None
            return None, "rate-limited", retry or 300
        return None, f"API error {e.code}", None
    except Exception:
        return None, "offline?", None

def fetch_cached(name, url, token):
    """Return (data, error). Serves cached data when fresh, rate-limited, or
    as a fallback on a transient failure — stale data beats an error pill."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, f"{name}.json")
    now = time.time()
    cached = {}
    try:
        with open(path) as f:
            cached = json.load(f)
    except Exception:
        pass

    if cached.get("data") and now - cached.get("fetched_at", 0) < CACHE_TTL:
        return cached["data"], None
    if now < cached.get("backoff_until", 0):
        if cached.get("data"):
            return cached["data"], None
        return None, "rate-limited — retrying later"

    data, err, retry_after = http_get_json(url, token)

    def save(payload):
        try:
            with open(path, "w") as f:
                json.dump(payload, f)
        except Exception:
            pass

    if data:
        save({"fetched_at": now, "data": data})
        return data, None
    if retry_after:
        save({**cached, "backoff_until": now + retry_after})
    if cached.get("data"):
        return cached["data"], None
    return None, err

# ---- parsing ----

def parse_claude(data):
    """Return {label: {"pct": float, "resets_at": datetime|None}}."""
    windows = {}
    for key, label in [("five_hour", "5-hour"), ("seven_day", "7-day"),
                        ("seven_day_opus", "7-day opus"), ("seven_day_sonnet", "7-day sonnet")]:
        w = data.get(key)
        if not w:
            continue
        resets = None
        if w.get("resets_at"):
            try:
                resets = datetime.fromisoformat(w["resets_at"].replace("Z", "+00:00"))
            except ValueError:
                pass
        windows[label] = {"pct": w.get("utilization", 0.0), "resets_at": resets}
    extra = data.get("extra_usage") or {}
    if extra.get("is_enabled") and extra.get("used_credits") is not None:
        limit = extra.get("monthly_limit") or 0
        windows["extra"] = {
            "credits": f"{extra['used_credits'] / 100:.2f} / {limit / 100:.0f} {extra.get('currency', '')}".strip(),
        }
    return windows

def window_label(seconds):
    for center, label in [(18000, "5-hour"), (604800, "7-day"), (2592000, "30-day")]:
        if abs(seconds - center) <= center * 0.05:
            return label
    return f"{seconds}s window"

def parse_codex(data):
    """Return {label: {"pct": float, "resets_at": datetime}}."""
    windows = {}
    rl = data.get("rate_limit") or {}
    for w in [rl.get("primary_window"), rl.get("secondary_window")]:
        if not w or not w.get("reset_at"):
            continue
        label = window_label(w.get("limit_window_seconds", 0))
        windows[label] = {
            "pct": w.get("used_percent", 0.0),
            "resets_at": datetime.fromtimestamp(w["reset_at"], tz=timezone.utc),
        }
    cr = data.get("code_review_rate_limit")
    if cr and cr.get("reset_at"):
        label = "review " + window_label(cr.get("limit_window_seconds", 0))
        windows[label] = {
            "pct": cr.get("used_percent", 0.0),
            "resets_at": datetime.fromtimestamp(cr["reset_at"], tz=timezone.utc),
        }
    return windows

# ---- rendering ----

# Menu bar icon: two thin vertical bars, bottom-up fill by usage. Claude is
# always orange (brand accent); Codex follows the menu bar's own foreground
# color (white in dark mode, black in light), like a normal monochrome
# status icon. No fill = no data / not logged in for that provider.
CLAUDE_COLOR = (255, 149, 0, 255)

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

def menu_bar_image(claude_pct, codex_pct):
    # Full bar = full remaining quota (good); it drains as usage climbs,
    # like a battery/fuel gauge rather than a "danger meter".
    claude_remaining = None if claude_pct is None else 100 - claude_pct
    codex_remaining = None if codex_pct is None else 100 - codex_pct
    fg = (255, 255, 255, 255) if is_dark_menu_bar() else (0, 0, 0, 255)
    bar_w, bar_h, gap = 8, 24, 4
    width, height = bar_w * 2 + gap, 32
    pixels = [[(0, 0, 0, 0)] * width for _ in range(height)]
    y = (height - bar_h) // 2
    draw_bar(pixels, 0, y, bar_w, bar_h, CLAUDE_COLOR, claude_remaining)
    draw_bar(pixels, bar_w + gap, y, bar_w, bar_h, fg, codex_remaining)
    return base64.b64encode(encode_png(width, height, pixels)).decode()

def meter(pct):
    filled = min(8, max(0, round(pct / (100 / 8))))
    return "█" * filled + "░" * (8 - filled)

def reset_str(dt):
    if dt is None:
        return ""
    local = dt.astimezone()
    day = "today" if local.date() == datetime.now().astimezone().date() else local.strftime("%a")
    return f"{day} {local.strftime('%H:%M')}"

def color_for(pct):
    if pct >= 90:
        return " color=red"
    if pct >= 70:
        return " color=orange"
    return ""

def window_line(label, w):
    if "credits" in w:
        return f"{label:<7} {w['credits']} | font=Menlo"
    pct = w["pct"]
    return (f"{label:<7} {meter(pct)} {pct:>3.0f}% "
            f"{reset_str(w.get('resets_at'))} | font=Menlo{color_for(pct)}")

def main():
    claude_token, claude_err = get_claude_token()
    codex_token, codex_err = get_codex_token()

    claude_windows, codex_windows = {}, {}
    if claude_token:
        data, err = fetch_cached("claude", CLAUDE_USAGE_URL, claude_token)
        if data:
            claude_windows = parse_claude(data)
        else:
            claude_err = err
    if codex_token:
        data, err = fetch_cached("codex", CODEX_USAGE_URL, codex_token)
        if data:
            codex_windows = parse_codex(data)
        else:
            codex_err = err

    # ---- menu bar icon ----
    def worst_pct(windows):
        vals = [w["pct"] for label, w in windows.items() if "pct" in w
                and label in ("5-hour", "7-day")]
        return max(vals) if vals else None

    claude_pct = worst_pct(claude_windows)
    codex_pct = worst_pct(codex_windows)
    try:
        print(f"| image={menu_bar_image(claude_pct, codex_pct)}")
    except Exception:
        # fallback: plain text if image rendering ever breaks
        c = f"{claude_pct:.0f}%" if claude_pct is not None else "⚠"
        x = f"{codex_pct:.0f}%" if codex_pct is not None else "⚠"
        print(f"C {c} · X {x}")
    print("---")

    print("Claude Code")
    if claude_err and not claude_windows:
        print(f"⚠ {claude_err} | color=orange")
    else:
        for label in ["5-hour", "7-day", "7-day opus", "7-day sonnet", "extra"]:
            if label in claude_windows:
                print(window_line(label, claude_windows[label]))
    print("View usage online | href=https://claude.ai/settings/usage")

    print("---")
    print("Codex")
    if codex_err and not codex_windows:
        print(f"⚠ {codex_err} | color=orange")
    else:
        for label, w in codex_windows.items():
            print(window_line(label, w))
    print("View usage online | href=https://chatgpt.com/codex/settings/usage")

    print("---")
    print("Refresh now | refresh=true")

if __name__ == "__main__":
    main()
