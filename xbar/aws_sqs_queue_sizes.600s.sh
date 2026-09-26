#!/usr/bin/env bash
# <xbar.title>Amazon SQS Queue Status</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Kiba Labs</xbar.author>
# <xbar.author.github>kibalabs</xbar.author.github>
# <xbar.dependencies>awscli,jq,awk</xbar.dependencies>

# TODO(krishan711): make this a parameter
aws_profiles=(tokenpage tokenpage-yieldseeker)

# Sparkline window/resolution for non-dl queues (matches the CloudWatch
# "ApproximateNumberOfMessagesVisible" chart in the SQS console).
sparkline_period_seconds=900
start_time=$(date -u -v-3H +%Y-%m-%dT%H:%M:%SZ)
end_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

sparkline() {
    local aws_profile="$1" queue_name="$2"
    local indices
    indices=$(aws cloudwatch get-metric-statistics \
        --profile "$aws_profile" \
        --namespace AWS/SQS \
        --metric-name ApproximateNumberOfMessagesVisible \
        --dimensions Name=QueueName,Value="$queue_name" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period "$sparkline_period_seconds" \
        --statistics Average 2>/dev/null \
        | jq -r '.Datapoints | sort_by(.Timestamp)[].Average' 2>/dev/null \
        | awk '
            { vals[++count] = $1 + 0 }
            END {
                if (count == 0) { exit }
                max = vals[1]; min = vals[1]
                for (i = 1; i <= count; i++) {
                    if (vals[i] > max) max = vals[i]
                    if (vals[i] < min) min = vals[i]
                }
                range = max - min
                for (i = 1; i <= count; i++) {
                    idx = (range == 0) ? 1 : int((vals[i] - min) / range * 7) + 1
                    printf "%d ", idx
                }
            }
        ')
    [ -z "$indices" ] && return
    # Block characters live here (bash handles multi-byte UTF-8 strings as
    # whole array elements) instead of inside awk, which splits by byte and
    # corrupts them.
    local blocks=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
    local out=""
    for idx in $indices; do
        out+="${blocks[idx-1]}"
    done
    echo "$out"
}

script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

if [ "$1" = "sso-login" ] && [ -n "$2" ]; then
    source ~/.bash_profile 1> /dev/null
    aws sso login --profile "$2"
    exit $?
fi

echo "☰"
echo "---"

source ~/.bash_profile 1> /dev/null

for aws_profile in "${aws_profiles[@]}"; do
    echo "$aws_profile | color=gray"
    region=$(aws configure get region --profile "$aws_profile" 2>/dev/null)
    list_raw=$(aws --profile "$aws_profile" sqs list-queues 2>&1)
    if ! jq -e . >/dev/null 2>&1 <<< "$list_raw"; then
        error_msg=$(echo "$list_raw" | tr -s '\n' ' ' | sed -e 's/^ *//' -e 's/ *$//' -e 's/^aws: \[ERROR\]: //')
        echo "⚠ $error_msg | color=orange font=Menlo"
        echo "Login to $aws_profile | bash=$script_path param1=sso-login param2=$aws_profile terminal=true refresh=true"
        echo "---"
        continue
    fi
    QUEUE_URLS=$(jq -r .QueueUrls <<< "$list_raw" | jq '.[]')

    # First pass: collect every queue's attributes so a "-dl" queue can be
    # grouped under its parent regardless of the order AWS returns them in.
    names=()
    urls=()
    depths=()
    inflights=()
    for QUEUE_URL in $QUEUE_URLS; do
        queueUrl=$(echo $QUEUE_URL | cut -d '"' -f 2)
        queueName=$(echo "${queueUrl##*/}")

        attributes=$(aws sqs --profile "$aws_profile" get-queue-attributes \
            --queue-url "$queueUrl" \
            --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
            | jq .Attributes)

        names+=("$queueName")
        urls+=("$queueUrl")
        depths+=("$(echo "$attributes" | jq '.ApproximateNumberOfMessages | tonumber')")
        inflights+=("$(echo "$attributes" | jq '.ApproximateNumberOfMessagesNotVisible | tonumber')")
    done

    count=${#names[@]}
    consumed=()
    for ((i = 0; i < count; i++)); do consumed[i]=0; done

    # Second pass: print each non-dl queue with its matching "-dl" stats
    # folded into the same line, and its chart directly beneath. Plain
    # lines with leading spaces, not "--" (which creates a real macOS
    # flyout submenu that needs a click/hover to reveal).
    for ((i = 0; i < count; i++)); do
        name="${names[i]}"
        [[ "$name" == *-dl ]] && continue

        spark=$(sparkline "$aws_profile" "$name")
        encodedQueueUrl=$(jq -rn --arg v "${urls[i]}" '$v | @uri')
        consoleUrl="https://${region}.console.aws.amazon.com/sqs/v2/home?region=${region}#/queues/${encodedQueueUrl}"

        dlSuffix=""
        dlName="${name}-dl"
        for ((j = 0; j < count; j++)); do
            if [ "${names[j]}" = "$dlName" ]; then
                dlSuffix=" (dl: ${depths[j]}/${inflights[j]})"
                consumed[j]=1
            fi
        done

        echo "$name: ${depths[i]}/${inflights[i]}$dlSuffix | font=Menlo href=$consoleUrl"
        if [ -n "$spark" ]; then
            echo "   $spark | font=Menlo href=$consoleUrl"
        fi
    done

    # Any "-dl" queue without a matching parent still gets shown, unindented.
    for ((i = 0; i < count; i++)); do
        if [[ "${names[i]}" == *-dl ]] && [ "${consumed[i]}" != "1" ]; then
            echo "${names[i]}: ${depths[i]} (${inflights[i]}) | font=Menlo"
        fi
    done

    echo "---"
done
echo "Refresh | refresh=true"
