import os
import logging

import asyncclick as click

from core.queues.sqs import SqsMessageQueue

@click.command()
@click.option('-q', '--queue-name', 'queueName', required=True, type=str)
@click.option('-a', '--account-id', 'accountId', required=True, type=str)
async def run(queueName: str, accountId: str):
    workQueue = SqsMessageQueue(region='eu-west-1', accessKeyId=os.environ['AWS_ACCESS_KEY_ID'], accessKeySecret=os.environ['AWS_ACCESS_KEY_SECRET'], queueUrl=f'https://sqs.eu-west-1.amazonaws.com/{accountId}/{queueName}')
    workQueueDl = SqsMessageQueue(region='eu-west-1', accessKeyId=os.environ['AWS_ACCESS_KEY_ID'], accessKeySecret=os.environ['AWS_ACCESS_KEY_SECRET'], queueUrl=f'https://sqs.eu-west-1.amazonaws.com/{accountId}/{queueName}-dl')

    await workQueue.connect()
    await workQueueDl.connect()

    while True:
        logging.info('Retrieving messages...')
        messages = await workQueueDl.get_messages(limit=10, expectedProcessingSeconds=2, longPollSeconds=0)
        if len(messages) == 0:
            break
        for message in messages:
            print('message', message)
            if message.content.get('registryAddress') == '0xBaa5DEcDffce1C099C82ef978c57475865334E36':
                print('Skipping bad registry: 0xBaa5DEcDffce1C099C82ef978c57475865334E36')
            else:
                await workQueue.send_message(message=message)
            await workQueueDl.delete_message(message=message)

    await workQueue.disconnect()
    await workQueueDl.disconnect()

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    run(_anyio_backend='asyncio')
