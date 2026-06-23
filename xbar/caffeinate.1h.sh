#!/bin/bash
# <xbar.title>Caffeinate</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Kiba Labs</xbar.author>
# <xbar.author.github>kibalabs</xbar.author.github>
# <xbar.dependencies>Bash GNU</xbar.dependencies>

if [ "$1" = 'caffeine' ]; then
  /usr/bin/killall caffeinate
  /usr/bin/caffeinate -dimsu
fi

if [ "$1" = 'stop' ]; then
  /usr/bin/killall caffeinate
fi

running_pids=$(pgrep caffeinate)
if [ -z "$running_pids" ]; then
  echo "⏾"
  echo '---'
  echo "Caffeinate | bash='$0' param1=caffeine terminal=false"
else
  echo "☕️"
  echo '---'
  echo "Stop | bash='$0' param1=stop terminal=false"
fi
