#!/bin/bash
# <xbar.title>Timezones</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Kiba Labs</xbar.author>
# <xbar.author.github>kibalabs</xbar.author.github>
# <xbar.dependencies>Bash GNU</xbar.dependencies>

echo "⧖"
echo "---"

echo -n "UTC  " ; TZ="UTC" date +'%H:%M'
echo -n "PST  " ; TZ="America/Los_Angeles" date +'%H:%M'
echo -n "EST  " ; TZ="America/New_York" date +'%H:%M'
echo -n "BRT  " ; TZ="America/Sao_Paulo" date +'%H:%M'
