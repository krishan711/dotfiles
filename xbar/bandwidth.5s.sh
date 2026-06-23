#!/usr/bin/env bash
# <xbar.title>Bandwidth</xbar.title>
# <xbar.version>v1.1</xbar.version>
# <xbar.author>Kiba Labs</xbar.author>
# <xbar.author.github>kibalabs</xbar.author.github>
# <xbar.dependencies>bash</xbar.dependencies>

INTERFACE="en0"
TMPFILE="/tmp/swiftbar_bandwidth_${INTERFACE}"
NOW=$(date +%s)

CURRENT=$(netstat -ib | awk -v iface="$INTERFACE" '$1 == iface && $3 ~ /Link/ {print $7, $10; exit}')
IN_BYTES=$(echo "$CURRENT" | awk '{print $1}')
OUT_BYTES=$(echo "$CURRENT" | awk '{print $2}')

format_rate() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then
        printf "%dB/s" "$bytes"
    elif [ "$bytes" -lt 1048576 ]; then
        printf "%dKB/s" "$(( bytes / 1024 ))"
    elif [ "$bytes" -lt 1073741824 ]; then
        printf "%dMB/s" "$(( bytes / 1048576 ))"
    else
        printf "%dGB/s" "$(( bytes / 1073741824 ))"
    fi
}

if [ -f "$TMPFILE" ]; then
    read PREV_TIME PREV_IN PREV_OUT < "$TMPFILE"
    DELTA_T=$(( NOW - PREV_TIME ))
    if [ "$DELTA_T" -gt 0 ] && [ -n "$IN_BYTES" ] && [ -n "$OUT_BYTES" ]; then
        IN_RATE=$(( (IN_BYTES - PREV_IN) / DELTA_T ))
        OUT_RATE=$(( (OUT_BYTES - PREV_OUT) / DELTA_T ))
        echo "▼ $(format_rate $IN_RATE) ▲ $(format_rate $OUT_RATE)"
    else
        echo "▼ -- ▲ --"
    fi
else
    echo "▼ -- ▲ --"
fi

echo "$NOW $IN_BYTES $OUT_BYTES" > "$TMPFILE"
echo "---"
echo "Open Activity Monitor | bash=open param1=-a param2='Activity Monitor' terminal=false refresh=false"
