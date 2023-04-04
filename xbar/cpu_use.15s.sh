#!/usr/bin/env bash
# <xbar.title>CPU Use</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Kiba Labs</xbar.author>
# <xbar.author.github>kibalabs</xbar.author.github>
# <xbar.dependencies>bash</xbar.dependencies>

ncpu=$(sysctl -n hw.logicalcpu)
total=$(ps -Ao %cpu= | paste -sd+ - | bc)
usage=$(echo "scale = 2; $total / $ncpu" | bc)
usageFormatted=$(printf "%0.1f%\n" "$usage")

echo "${usageFormatted}%"
echo "---"

# NOTE(krishan711): can't figure out why this gets truncated
processes=$(ps -Areww -o pcpu=,ucomm= | head -n 10)
IFS=$'\n' processes=($processes)

for process in "${processes[@]}"; do
    echo $process
done

echo "Refresh | refresh=true"
