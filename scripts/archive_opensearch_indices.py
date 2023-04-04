import asyncio
import logging
import os

from core.requester import Requester
from core.slack_client import SlackClient
from core.util import date_util
from core.aws_requester import AwsRequester


OPENSEARCH_URL = 'https://vpc-kiba-logs-iz46qlwv7gq2xvvtrtlduv4lbq.eu-west-1.es.amazonaws.com'

async def post():
    requester = Requester()

    awsRequester = AwsRequester(accessKeyId=os.environ['AWS_KEY'], accessKeySecret=os.environ['AWS_SECRET'])
    slackClient = SlackClient(webhookUrl=os.environ['SLACK_WEBHOOK_URL'], requester=requester, defaultSender='worker', defaultChannel='kiba-dev')

    # await awsRequester.make_request(method='PUT', url=f'{OPENSEARCH_URL}/_snapshot/kiba-logs', dataDict={
    #     "type": "s3",
    #     "settings": {
    #         "bucket": "kiba-logs",
    #         "region": "eu-west-1",
    #         "role_arn": "arn:aws:iam::097520841056:role/opensearch-snapshot-role"
    #     }
    # }, headers={'Content-Type': 'application/json'}, service='es', region='eu-west-1')

    indicesResponse = await requester.get(f'{OPENSEARCH_URL}/logstash-*')
    indicesJson = indicesResponse.json()
    indexNames = list(indicesJson.keys())
    archivedIndexNames = []
    logging.info(f'Looking at {len(indexNames)} indices: {", ".join(indexNames)}')
    for indexName in indexNames:
        indexDate = date_util.datetime_from_string(dateString=indexName.replace('logstash-', ''), dateFormat='%Y.%m.%d')
        if indexDate < date_util.datetime_from_now(days=-7):
            logging.info(f'Archiving {indexName}...')
            await requester.make_request(method='PUT', url=f'{OPENSEARCH_URL}/_snapshot/kiba-logs/{indexName}?wait_for_completion=true', dataDict={
                "indices": indexName,
                "ignore_unavailable": True,
                "include_global_state": False,
            }, timeout=600, headers={'Content-Type': 'application/json'})
            await requester.make_request(method='DELETE', url=f'{OPENSEARCH_URL}/{indexName}', timeout=600)
            archivedIndexNames.append(indexName)
    text = f'Archived {len(archivedIndexNames)} indices: {", ".join(archivedIndexNames)}.\n{len(indexNames) - len(archivedIndexNames)} indices remaining.'
    await slackClient.post(text)
    await requester.close_connections()
    await awsRequester.close_connections()

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    asyncio.run(post())
