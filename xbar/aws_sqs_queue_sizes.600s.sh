#!/bin/bash
# <xbar.title>Amazon SQS Queue Status</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Kiba Labs</xbar.author>
# <xbar.author.github>kibalabs</xbar.author.github>
# <xbar.desc>Shows current queue stats for all your AWS SQS queues.</xbar.desc>
# <xbar.dependencies>awscli,jq</xbar.dependencies>
export PATH="$PATH:/usr/local/bin"

AWS_PROFILE="kiba"
export AWS_PROFILE

echo "SQS"
echo "---"
QUEUE_URLS=$(aws sqs list-queues | jq -r .QueueUrls | jq '.[]')
for QUEUE_URL in $QUEUE_URLS; do
    queueUrl=$(echo $QUEUE_URL | cut -d '"' -f 2)
    queueName=$(echo "${queueUrl##*/}")

    attributes=$(aws sqs get-queue-attributes \
        --queue-url "$queueUrl" \
        --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
        | jq .Attributes)

    depth=$(echo "$attributes" | jq '.ApproximateNumberOfMessages | tonumber')
    inflight=$(echo "$attributes" | jq '.ApproximateNumberOfMessagesNotVisible | tonumber')
    echo "$queueName: $depth ($inflight)"
done
