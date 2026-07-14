#!/usr/bin/env python3
# <xbar.title>AI Usage (Claude + Codex)</xbar.title>
# <xbar.version>v2.0</xbar.version>
# <xbar.author>Kiba Labs</xbar.author>
# <xbar.author.github>kibalabs</xbar.author.github>
# <xbar.desc>5-hour and weekly quota for Claude Code and Codex CLI, read via their own OAuth logins.</xbar.desc>
# <xbar.dependencies>python3</xbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
#
# Read-only: reuses whichever OAuth token `claude` / `codex` already logged
# in with and queries the same internal usage endpoints their own status
# screens use.
#
#   Claude Code -> macOS Keychain "Claude Code-credentials" by default
#                  (falls back to $CLAUDE_CONFIG_DIR/.credentials.json)
#                  -> GET https://api.anthropic.com/api/oauth/usage
#   Codex CLI   -> $CODEX_HOME/auth.json (default ~/.codex/auth.json)
#                  -> GET https://chatgpt.com/backend-api/wham/usage
#
# Both endpoints are undocumented/internal to their respective CLIs, so a
# future update may require a small fix here. No caching: every run is a
# live fetch. On failure (rate-limited, offline, auth issue) each section
# just shows an error plus a "View usage online" link -- runs on a 15-minute
# background cadence, and "Refresh now" re-runs the same live fetch on
# demand.
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
import shlex
import shutil
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zlib

from datetime import datetime, timezone

CLAUDE_USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
CLAUDE_REFRESH_URL = "https://platform.claude.com/v1/oauth/token"
CLAUDE_OAUTH_CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
CODEX_USAGE_URL = "https://chatgpt.com/backend-api/wham/usage"
GITHUB_API_BASE = "https://api.github.com"
GITHUB_COPILOT_MONTHLY_LIMIT = 1500.0
GITHUB_SOURCE_FILE = os.path.expanduser("~/.bash_secrets")


def load_pointer_config():
    """Paths only, never secrets: ~/.config/ai-usage-xbar/config.json."""
    path = os.path.expanduser("~/.config/ai-usage-xbar/config.json")
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}

POINTER_CONFIG = load_pointer_config()

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

def load_claude_auth():
    """Return (auth_dict, source_tuple, error).

    source_tuple is one of:
    - ("token_file", path)
    - ("keychain", account)
    - ("file", path)
    """
    override = claude_token_file()
    if override:
        try:
            with open(os.path.expanduser(override)) as f:
                token = f.read().strip()
        except OSError:
            return None, None, f"claude_token_file not readable: {override}"
        if not token:
            return None, None, "claude_token_file is empty"
        return {"accessToken": token}, ("token_file", override), None

    raw = None
    source = None
    for account in ("unknown", None):
        try:
            args = ["security", "find-generic-password", "-s", claude_keychain_service()]
            if account:
                args.extend(["-a", account])
            args.append("-w")
            out = subprocess.run(
                args,
                capture_output=True, text=True, timeout=10,
            )
            if out.returncode == 0:
                raw = out.stdout.strip()
                source = ("keychain", account)
                break
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
    if raw is None:
        cred_path = os.path.join(claude_config_dir(), ".credentials.json")
        try:
            with open(cred_path) as f:
                raw = f.read()
            source = ("file", cred_path)
        except OSError:
            return None, None, "not logged in — run `claude` once and /login"
    try:
        creds = json.loads(raw)["claudeAiOauth"]
    except (json.JSONDecodeError, KeyError, TypeError):
        return None, None, "unexpected credential format"
    if not creds.get("accessToken"):
        return None, None, "not logged in — run `claude` once and /login"
    return creds, source, None

def save_claude_auth(auth, source):
    payload = json.dumps({"claudeAiOauth": auth}, separators=(",", ":"))
    kind, path = source
    if kind == "keychain":
        account = path or "unknown"
        out = subprocess.run(
            [
                "security", "add-generic-password", "-U",
                "-s", claude_keychain_service(),
                "-a", account,
                "-w", payload,
            ],
            capture_output=True, text=True, timeout=10,
        )
        if out.returncode != 0:
            raise RuntimeError(out.stderr.strip() or "keychain write failed")
        return
    if kind == "file":
        with open(path, "w") as f:
            f.write(payload)
        return
    # token_file source is intentionally read-only; never rewrite it.

def refresh_claude_auth(auth, source):
    refresh_token = auth.get("refreshToken")
    if not refresh_token or source[0] == "token_file":
        return auth, "token rejected — log in again"
    body = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
        "client_id": CLAUDE_OAUTH_CLIENT_ID,
    }).encode()
    req = urllib.request.Request(
        CLAUDE_REFRESH_URL,
        data=body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
            "User-Agent": "Claude Code/1.0 (macOS)",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            wire = json.loads(resp.read())
    except urllib.error.HTTPError:
        return auth, "token rejected — log in again"
    except Exception:
        return auth, "offline?"
    if not wire.get("access_token"):
        return auth, "token rejected — log in again"
    auth["accessToken"] = wire["access_token"]
    auth["refreshToken"] = wire.get("refresh_token") or refresh_token
    if wire.get("expires_in"):
        auth["expiresAt"] = int(time.time() * 1000 + int(wire["expires_in"]) * 1000)
    try:
        save_claude_auth(auth, source)
    except Exception:
        return auth, "token refresh succeeded but could not persist credential"
    return auth, None

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

def get_github_token():
    """Return (token, error) by sourcing ~/.bash_secrets locally at runtime.
    The widget may read the resulting GitHub token value, but should never read
    or print the secret file contents directly. Prefer a dedicated billing
    token from GITHUB_TOKEN_PLAN over a legacy GITHUB_TOKEN."""
    if os.environ.get("GITHUB_TOKEN_PLAN"):
        return os.environ["GITHUB_TOKEN_PLAN"], None
    source_file = os.path.expanduser(
        os.environ.get("AI_USAGE_GITHUB_SOURCE_FILE")
        or POINTER_CONFIG.get("github_source_file")
        or GITHUB_SOURCE_FILE
    )
    cmd = (
        f"source {shlex.quote(source_file)} >/dev/null 2>&1; "
        'printf %s "${GITHUB_TOKEN_PLAN:-$GITHUB_TOKEN}"'
    )
    try:
        out = subprocess.run(
            ["/bin/bash", "-lc", cmd],
            capture_output=True, text=True, timeout=10,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        out = None
    if out:
        token = out.stdout.strip()
        if token:
            return token, None
    if os.environ.get("GITHUB_TOKEN"):
        return os.environ["GITHUB_TOKEN"], None
    if out is None:
        return None, "could not source ~/.bash_secrets"
    return None, "no GITHUB_TOKEN_PLAN or GITHUB_TOKEN in ~/.bash_secrets"

# ---- fetching (no data caching — every call goes live) ----
#
# The one piece of state kept on disk is a bare backoff deadline per
# endpoint, never response data. Anthropic's usage endpoint has been
# observed to re-arm its own Retry-After lockout on *every* request it
# receives, including failed ones (anthropics/claude-code#31637) -- so a
# client that just keeps retrying on a fixed interval can keep it 429ing
# forever. Respecting Retry-After (and not probing again before it elapses)
# is what lets the lockout actually clear.

BACKOFF_DIR = os.path.expanduser("~/.cache/ai-usage-xbar")

def backoff_path(name):
    return os.path.join(BACKOFF_DIR, f"{name}.backoff.json")

def read_backoff(name):
    try:
        with open(backoff_path(name)) as f:
            return json.load(f).get("until", 0)
    except Exception:
        return 0

def write_backoff(name, until):
    try:
        os.makedirs(BACKOFF_DIR, exist_ok=True)
        with open(backoff_path(name), "w") as f:
            json.dump({"until": until}, f)
    except Exception:
        pass

def clear_backoff(name):
    try:
        os.remove(backoff_path(name))
    except Exception:
        pass

def http_get_json(url, token, backoff_name=None):
    """Return (data, error). No response data is ever cached -- a failure
    here is surfaced directly to the dropdown as an error with a "View
    usage online" fallback link. If backoff_name is set and a prior 429
    told us to wait, skip the request entirely until that deadline passes."""
    if backoff_name:
        until = read_backoff(backoff_name)
        if until > time.time():
            wait_min = int((until - time.time()) / 60) + 1
            return None, f"rate-limited — retry in ~{wait_min}m"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    })
    if url == CLAUDE_USAGE_URL:
        req.add_header("anthropic-beta", "oauth-2025-04-20")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            if backoff_name:
                clear_backoff(backoff_name)
            return json.loads(resp.read()), None
    except urllib.error.HTTPError as e:
        if e.code == 401:
            return None, "token rejected — log in again"
        if e.code == 429:
            if backoff_name:
                retry_after = int(e.headers.get("Retry-After", 60) or 60)
                write_backoff(backoff_name, time.time() + retry_after)
            return None, "rate-limited by upstream"
        return None, f"API error {e.code}"
    except Exception:
        return None, "offline?"

def github_get_json(path, token):
    req = urllib.request.Request(
        GITHUB_API_BASE + path,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2026-03-10",
        },
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read())

def fetch_github_copilot(token):
    """Return ({login, usage}, error). Always live."""
    try:
        user = github_get_json("/user", token)
        login = user["login"]
        usage = github_get_json(f"/users/{login}/settings/billing/premium_request/usage", token)
        return {"login": login, "usage": usage}, None
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            return None, "token rejected or lacks billing access"
        return None, f"API error {e.code}"
    except Exception:
        return None, "offline?"

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
        row = {"pct": w.get("utilization", 0.0), "resets_at": resets}
        if resets is None:
            row["reset_label"] = "no reset yet"
        windows[label] = row
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

def parse_github_copilot(data):
    """Return compact current-month Copilot premium-request usage summary."""
    usage = data.get("usage") or {}
    items = usage.get("usageItems") or []
    total_requests = sum(float(item.get("grossQuantity", 0) or 0) for item in items)
    billable_requests = sum(float(item.get("netQuantity", 0) or 0) for item in items)
    billable_amount = sum(float(item.get("netAmount", 0) or 0) for item in items)

    limit = GITHUB_COPILOT_MONTHLY_LIMIT

    used_pct = min(100.0, 100.0 * total_requests / limit) if limit > 0 else 0.0
    return {
        "login": data.get("login"),
        "total_requests": total_requests,
        "billable_requests": billable_requests,
        "billable_amount": billable_amount,
        "monthly_limit": limit,
        "used_pct": used_pct,
    }

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
    reset = w.get("reset_label") or reset_str(w.get("resets_at"))
    return (f"{label:<7} {meter(pct)} {pct:>3.0f}% "
            f"{reset} | font=Menlo{color_for(pct)}")

def cli_path(name):
    return shutil.which(name) or name

def run_action(action):
    if action == "claude-auth-login":
        raise SystemExit(subprocess.run([cli_path("claude"), "auth", "login"]).returncode)
    if action == "claude-refresh-ping":
        raise SystemExit(subprocess.run([cli_path("claude"), "-p", "Reply with exactly: hi"]).returncode)

def main():
    if len(sys.argv) > 1:
        run_action(sys.argv[1])

    claude_auth, claude_source, claude_err = load_claude_auth()
    codex_token, codex_err = get_codex_token()
    github_token, github_err = get_github_token()
    claude_windows, codex_windows = {}, {}
    github_copilot = None
    if claude_auth:
        expires_at = claude_auth.get("expiresAt")
        data = None
        err = None
        if expires_at and expires_at / 1000 < time.time():
            claude_auth, refresh_err = refresh_claude_auth(claude_auth, claude_source)
            if refresh_err:
                claude_err = refresh_err
            else:
                data, err = http_get_json(
                    CLAUDE_USAGE_URL,
                    claude_auth["accessToken"],
                    backoff_name="claude",
                )
        else:
            data, err = http_get_json(
                CLAUDE_USAGE_URL,
                claude_auth["accessToken"],
                backoff_name="claude",
            )
        if not claude_err and not data and err == "token rejected — log in again":
            claude_auth, refresh_err = refresh_claude_auth(claude_auth, claude_source)
            if refresh_err:
                err = refresh_err
            else:
                data, err = http_get_json(
                    CLAUDE_USAGE_URL,
                    claude_auth["accessToken"],
                    backoff_name="claude",
                )
        if data:
            claude_windows = parse_claude(data)
        elif not claude_err:
            claude_err = err
    if codex_token:
        data, err = http_get_json(CODEX_USAGE_URL, codex_token, backoff_name="codex")
        if data:
            codex_windows = parse_codex(data)
        else:
            codex_err = err
    if github_token:
        data, err = fetch_github_copilot(github_token)
        if data:
            github_copilot = parse_github_copilot(data)
        else:
            github_err = err

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
        c = f"{claude_pct:.0f}%" if claude_pct is not None else "⚠"
        x = f"{codex_pct:.0f}%" if codex_pct is not None else "⚠"
        print(f"C {c} · X {x}")
    print("---")

    script = os.path.realpath(__file__)
    print("Claude Code")
    claude_auth_error = claude_err and not claude_windows and not claude_err.startswith("rate-limited")
    if claude_err and not claude_windows:
        print(f"⚠ {claude_err} | color=orange")
        if claude_auth_error:
            print(f"Claude auth login | bash={script} param1=claude-auth-login terminal=true refresh=true")
            print(f"Claude refresh ping | bash={script} param1=claude-refresh-ping terminal=true refresh=true")
            print("Run the ping once after login to refresh Claude's cached access token | color=gray font=Menlo")
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
    print("GitHub Copilot")
    if github_err and not github_copilot:
        print(f"⚠ {github_err} | color=orange")
    elif github_copilot:
        print(
            f"month   {meter(github_copilot['used_pct']):<8} "
            f"{github_copilot['used_pct']:.0f}%  "
            f"{github_copilot['total_requests']:.0f}/{github_copilot['monthly_limit']:.0f} "
            f"| font=Menlo{color_for(github_copilot['used_pct'])}"
        )
        print(f"billed  ${github_copilot['billable_amount']:.2f} | font=Menlo")
    print("View usage online | href=https://github.com/settings/billing/premium_requests_usage")

    print("---")
    print(f"Refresh now | bash={script} terminal=false refresh=true")

if __name__ == "__main__":
    main()
