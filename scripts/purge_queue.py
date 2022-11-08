import os
import logging

import boto3
import asyncclick as click

from core.queues.sqs_message_queue import SqsMessageQueue

@click.command()
@click.option('-q', '--queue-name', 'queueName', required=True, type=str)
async def purge_queue(queueName: str):
    sqsClient = boto3.client(service_name='sqs', region_name='eu-west-1', aws_access_key_id=os.environ['AWS_KEY'], aws_secret_access_key=os.environ['AWS_SECRET'])
    queue = SqsMessageQueue(sqsClient=sqsClient, queueUrl=f'https://sqs.eu-west-1.amazonaws.com/097520841056/{queueName}')

    while True:
        logging.info('Retrieving messages...')
        messages = await queue.get_messages(limit=10, expectedProcessingSeconds=2, longPollSeconds=0)
        if len(messages) == 0:
            return
        for message in messages:
            print('message', message)
            await queue.delete_message(message=message)

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    purge_queue(_anyio_backend='asyncio')
