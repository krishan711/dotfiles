import asyncio
import json
import os
import subprocess
import random
import logging
import shutil
from typing import Dict
from typing import Optional

import asyncclick as click
import requests
from core.s3_manager import S3Manager


async def copy_s3_bucket(sourceBucket: str, destinationBucket: str, sourcePath: Optional[str], destinationPath: Optional[str], awsKey: str, awsSecret: str) -> None:
    fullSourcePath = f's3://{sourceBucket}'
    if sourcePath:
        fullSourcePath = f'{fullSourcePath}/{sourcePath}'
    else:
        sourcePath = ''
    fullDestinationPath = f's3://{destinationBucket}'
    if destinationPath:
        fullDestinationPath = f'{fullDestinationPath}/{destinationPath}'
    logging.info(f'Copying {fullSourcePath} to {fullDestinationPath}')

    s3Manager = S3Manager(region='eu-west-1', accessKeyId=awsKey, accessKeySecret=awsSecret)

    await s3Manager.connect()
    async for sourceFile in s3Manager.generate_directory_files(s3Directory=fullSourcePath):
        print('sourceFile', sourceFile)
        if sourceFile.path.endswith('/'):
            continue
        grants = await s3Manager.get_file_grants(f's3://{sourceFile.bucket}/{sourceFile.path}')
        accessControl = None
        if any(grant.permission == 'READ' and grant.granteeURI == 'http://acs.amazonaws.com/groups/global/AllUsers' for grant in grants):
            accessControl = 'public-read'
        headers = await s3Manager.head_file(f's3://{sourceFile.bucket}/{sourceFile.path}')
        cacheControl = None
        contentType = None
        for header in headers.keys():
            if header == 'cache-control':
                cacheControl = headers[header]
            elif header == 'content-type':
                contentType = headers[header]
        await s3Manager.copy_file(source=f's3://{sourceFile.bucket}/{sourceFile.path}', target=f's3://{destinationBucket}/{sourceFile.path.replace(sourcePath, "").strip("/")}', accessControl=accessControl, cacheControl=cacheControl, contentType=contentType)

    await s3Manager.disconnect()


@click.command()
@click.option('-s', '--source-bucket', 'sourceBucket', required=True, type=str)
@click.option('-sf', '--source-path', 'sourcePath', required=False, type=str)
@click.option('-d', '--destination-bucket', 'destinationBucket', required=True, type=str)
@click.option('-df', '--destination-path', 'destinationPath', required=False, type=str)
@click.option('-ak', '--aws-key', 'awsKey', required=True, type=str, default=lambda: os.environ['AWS_KEY'])
@click.option('-as', '--aws-secret', 'awsSecret', required=True, type=str, default=lambda: os.environ['AWS_SECRET'])
@click.option('-v', '--verbose', 'verbose', required=False, is_flag=True, default=False)
async def run(sourceBucket: str, destinationBucket: str, sourcePath: Optional[str], destinationPath: Optional[str], awsKey: str, awsSecret: str, verbose: bool):
    logging.basicConfig(level=logging.DEBUG if verbose else logging.INFO)
    await copy_s3_bucket(sourceBucket=sourceBucket, destinationBucket=destinationBucket, sourcePath=sourcePath, destinationPath=destinationPath, awsKey=awsKey, awsSecret=awsSecret)

if __name__ == '__main__':
    asyncio.run(run())
