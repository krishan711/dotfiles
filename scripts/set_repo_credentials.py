import json
import os
import subprocess
import logging

import click
import requests
from base64 import b64encode
from nacl import encoding, public
from core.util import file_util


def _encrypt_secret(publicKey: str, value: str) -> str:
    publicKey = public.PublicKey(publicKey.encode("utf-8"), encoding.Base64Encoder())
    sealedBox = public.SealedBox(publicKey)
    encrypted = sealedBox.encrypt(value.encode("utf-8"))
    return b64encode(encrypted).decode("utf-8")


def set_repo_credentials(organization: str, repoName: str, githubApiToken: str) -> None:
    logging.info(f'Updating GitHub repo: {organization}/{repoName}')

    githubHeaders = {
        'Accept': 'application/vnd.github.v3.full+json',
        'Authorization': f'token {githubApiToken}',
    }

    response = requests.get(url=f'https://api.github.com/repos/{organization}/{repoName}/actions/secrets/public-key', headers=githubHeaders)
    response.raise_for_status()
    responseJson = response.json()
    key = responseJson['key']
    keyId = responseJson['key_id']

    subprocess.check_output(f'ssh-keygen -t ed25519 -C github-actions-{repoName} -f github-actions-{repoName} -N ""', stderr=subprocess.STDOUT, shell=True)
    with open(f'github-actions-{repoName}.pub', 'r') as f:
        publicSshKey = f.read()
    file_util.remove_file_sync(f'github-actions-{repoName}.pub')
    with open(f'github-actions-{repoName}', 'r') as f:
        privateSshKey = f.read()
    file_util.remove_file_sync(f'github-actions-{repoName}')

    secrets = {
        'APIBOX_URL': _encrypt_secret(publicKey=key, value=os.environ['APIBOX_URL']),
        'APIBOX_PORT': _encrypt_secret(publicKey=key, value=os.environ['APIBOX_PORT']),
        'APIBOX_USER': _encrypt_secret(publicKey=key, value=os.environ['APIBOX_USER']),
        'APIBOX_SSH_KEY': _encrypt_secret(publicKey=key, value=privateSshKey),
        'WORKERBOX_URL': _encrypt_secret(publicKey=key, value=os.environ['WORKERBOX_URL']),
        'WORKERBOX_PORT': _encrypt_secret(publicKey=key, value=os.environ['WORKERBOX_PORT']),
        'WORKERBOX_USER': _encrypt_secret(publicKey=key, value=os.environ['WORKERBOX_USER']),
        'WORKERBOX_SSH_KEY': _encrypt_secret(publicKey=key, value=privateSshKey),
        'CERTBOX_URL': _encrypt_secret(publicKey=key, value=os.environ['CERTBOX_URL']),
        'CERTBOX_PORT': _encrypt_secret(publicKey=key, value=os.environ['CERTBOX_PORT']),
        'CERTBOX_USER': _encrypt_secret(publicKey=key, value=os.environ['CERTBOX_USER']),
        'CERTBOX_SSH_KEY': _encrypt_secret(publicKey=key, value=privateSshKey),
        'MDTPBOX_URL': _encrypt_secret(publicKey=key, value=os.environ['MDTPBOX_URL']),
        'MDTPBOX_PORT': _encrypt_secret(publicKey=key, value=os.environ['MDTPBOX_PORT']),
        'MDTPBOX_USER': _encrypt_secret(publicKey=key, value=os.environ['MDTPBOX_USER']),
        'MDTPBOX_SSH_KEY': _encrypt_secret(publicKey=key, value=privateSshKey),
    }

    for secretName, secretValue in secrets.items():
        response = requests.put(url=f'https://api.github.com/repos/{organization}/{repoName}/actions/secrets/{secretName}', headers=githubHeaders, data=json.dumps({
            'encrypted_value': secretValue,
            'key_id': keyId,
        }))
        response.raise_for_status()

    logging.info(f'save this to apibox and/or workerbox and/or certbox:')
    logging.info(publicSshKey)


@click.command()
@click.option('-o', '--organization', 'organization', required=True, type=str, default='krishan711')
@click.option('-n', '--name', 'repoName', required=True, type=str)
@click.option('-g', '--github-api-token', 'githubApiToken', required=True, type=str, default=lambda: os.environ['GITHUB_TOKEN'], show_default='GITHUB_TOKEN in your environment variables')
@click.option('-v', '--verbose', 'verbose', required=False, is_flag=True, default=False)
def run(organization: str, repoName: str, verbose: bool, githubApiToken: str):
    logging.basicConfig(level=logging.DEBUG if verbose else logging.INFO)
    set_repo_credentials(organization=organization, repoName=repoName, githubApiToken=githubApiToken)

if __name__ == '__main__':
    run()
