#!/usr/bin/env bash

BRAVE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

echo "Applying Brave policies..."

if [[ "$OS" == "Darwin" ]]; then
    # macOS: policies go in a plist at /Library/Managed Preferences/
    sudo python3 - <<EOF
import json, plistlib, pathlib

with open('${BRAVE_DIR}/policies.json') as f:
    data = json.load(f)

dest = pathlib.Path('/Library/Managed Preferences/com.brave.Browser.plist')
dest.parent.mkdir(parents=True, exist_ok=True)
with open(dest, 'wb') as f:
    plistlib.dump(data, f)

print(f'  Written: {dest}')
EOF

    BRAVE_PREFS="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/Default/Preferences"
    BRAVE_PROCESS="Brave Browser"

elif [[ "$OS" == "Linux" ]]; then
    # Linux: policies go in a JSON file at /etc/brave/policies/managed/
    POLICY_DIR="/etc/brave/policies/managed"
    sudo mkdir -p "$POLICY_DIR"
    sudo cp "${BRAVE_DIR}/policies.json" "$POLICY_DIR/dotfiles.json"
    echo "  Written: $POLICY_DIR/dotfiles.json"

    BRAVE_PREFS="$HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences"
    BRAVE_PROCESS="brave-browser"
fi

echo "Applying Brave preference overrides..."

if [ ! -f "$BRAVE_PREFS" ]; then
    echo "  Skipping: Brave preferences file not found (open Brave once first)"
    exit 0
fi

if pgrep -x "$BRAVE_PROCESS" > /dev/null; then
    echo "  Skipping preference overrides: Brave is running — close it and rerun to apply"
    exit 0
fi

python3 - <<EOF
import json

def deep_merge(base, override):
    for key, value in override.items():
        if key in base and isinstance(base[key], dict) and isinstance(value, dict):
            deep_merge(base[key], value)
        else:
            base[key] = value

with open('${BRAVE_PREFS}') as f:
    prefs = json.load(f)

with open('${BRAVE_DIR}/preferences-overrides.json') as f:
    overrides = json.load(f)

deep_merge(prefs, overrides)

with open('${BRAVE_PREFS}', 'w') as f:
    json.dump(prefs, f, separators=(',', ':'))

print('  Preference overrides applied.')
EOF
