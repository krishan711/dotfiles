#!/usr/bin/env bash
# <xbar.title>Amazon SQS Queue Status</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Kiba Labs</xbar.author>
# <xbar.author.github>kibalabs</xbar.author.github>
# <xbar.dependencies>awscli,jq</xbar.dependencies>

# TODO(krishan711): make this a parameter
aws_profile=tokenpage

echo "☰"
echo "---"

source ~/.bash_profile 1> /dev/null

QUEUE_URLS=$(aws --profile $aws_profile sqs list-queues | jq -r .QueueUrls | jq '.[]')

for QUEUE_URL in $QUEUE_URLS; do
    queueUrl=$(echo $QUEUE_URL | cut -d '"' -f 2)
    queueName=$(echo "${queueUrl##*/}")

    attributes=$(aws sqs --profile $aws_profile get-queue-attributes \
        --queue-url "$queueUrl" \
        --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
        | jq .Attributes)

    depth=$(echo "$attributes" | jq '.ApproximateNumberOfMessages | tonumber')
    inflight=$(echo "$attributes" | jq '.ApproximateNumberOfMessagesNotVisible | tonumber')
    echo "$queueName: $depth ($inflight)"
done
echo "Refresh | refresh=true"
