import asyncio
import logging
import os
import time

import boto3
from core.requester import Requester
from core.slack_client import SlackClient


async def post():
    sqsClient = boto3.client(service_name='sqs', region_name='eu-west-1', aws_access_key_id=os.environ['AWS_KEY'], aws_secret_access_key=os.environ['AWS_SECRET'])
    requester = Requester()
    slackClient = SlackClient(webhookUrl=os.environ['SLACK_WEBHOOK_URL'], requester=requester, defaultSender='worker', defaultChannel='notd-notifications')
    sqsResponse = sqsClient.list_queues()
    sqsQueueUrls = sqsResponse.get("QueueUrls")
    queueSizes = dict()
    for sqsQueueUrl in sqsQueueUrls:
        queueAttributes = sqsClient.get_queue_attributes(QueueUrl=sqsQueueUrl, AttributeNames=['ApproximateNumberOfMessages'])
        queueSize = queueAttributes.get("Attributes").get("ApproximateNumberOfMessages")
        queueSizes[sqsQueueUrl] = queueSize
    queueSizesText = "\n".join([f'{name.split("/")[-1]}: {size}' for name, size in queueSizes.items()])
    text = f'AWS SQS Stats:\n```{queueSizesText}```'
    await slackClient.post(text)
    await requester.close_connections()

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    asyncio.run(post())
