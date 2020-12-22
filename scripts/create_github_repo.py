import json
import os
import subprocess
import random
import logging
import shutil

import click
import requests

# NOTE(krishan711): The colors are used as the keys. DO NOT CHANGE THEM!
KIBA_LABELS = [{
    'color': 'cfd3d7',
    'name': ':v: duplicate',
    'description': 'This issue or pull request already exists',
}, {
    'color': 'a2eeef',
    'name': ':sparkles: enhancement',
    'description': 'New feature or request',
}, {
    'color': 'd876e3',
    'name': ':question: question',
    'description': 'Further information is requested',
}, {
    'color': 'd73a4a',
    'name': ':bug: bug',
    'description': "Something isn't working",
}, {
    'color': '008672',
    'name': ':wave: help wanted',
    'description': 'Extra attention is needed',
}, {
    'color': '7057ff',
    'name': ':mortar_board: good first issue',
    'description': 'Good for newcomers',
}, {
    'color': 'ffffff',
    'name': ':skull: wontfix',
    'description': 'This will not be worked on',
}, {
    'color': '0075ca',
    'name': ':books: documentation',
    'description': 'Improvements or additions to documentation',
}, {
    'color': '82ea75',
    'name': ':construction: wip',
    'description': "Work In Progress (don't merge)",
}, {
    'color': 'e4e669',
    'name': ':dizzy_face: invalid',
    'description': "This doesn't seem right",
}]


def create_github_repo(organization: str, name: str, githubApiToken: str) -> None:
    logging.info(f'Updating GitHub repo: {organization}/{name}')
    githubHeaders = {
        'Accept': 'application/vnd.github.v3.full+json',
        'Authorization': f'token {githubApiToken}',
    }
    githubHeadersLokiPreview = {
        'Accept': 'application/vnd.github.london-preview+json',
        'Authorization': f'token {githubApiToken}',
    }
    primaryBranch = 'main'

    repoResponse = requests.get(url=f'https://api.github.com/repos/{organization}/{name}', headers=githubHeaders)
    isExistingRepo = repoResponse.status_code != 404
    if not isExistingRepo:
        logging.info(f'Creating repo: {organization}/{name}')
        requests.post(url=f'https://api.github.com/orgs/{organization}/repos', headers=githubHeaders, data=json.dumps({
            'name': name,
            'private': True,
            'auto_init': False
        })).raise_for_status()
        repoDirectory = os.path.join(os.getcwd(), 'tmp')
        shutil.rmtree(repoDirectory, ignore_errors=True)
        logging.debug(f'Working in {repoDirectory}')
        subprocess.check_output(f'git clone git@github.com:{organization}/{name}.git {repoDirectory}', stderr=subprocess.STDOUT, shell=True)
        with open(os.path.join(repoDirectory, 'README.md'), 'w') as f:
            f.write(f'# {name.title()}')
        subprocess.check_output(f'git checkout -b {primaryBranch} && git add -A . && git commit -am "Initial commmit" && git push --set-upstream origin {primaryBranch}', stderr=subprocess.STDOUT, shell=True, cwd=repoDirectory)
        shutil.rmtree(repoDirectory, ignore_errors=True)

    # Update settings
    response = requests.patch(url=f'https://api.github.com/repos/{organization}/{name}', headers=githubHeaders, data=json.dumps({
        'name': name,
        'has_wiki': False,
        'has_issues': True,
        'has_projects': False,
        'default_branch': primaryBranch,
        'allow_rebase_merge': False,
        'allow_squash_merge': True,
        'allow_merge_commit': False,
        'delete_branch_on_merge': True,
        'description': '',
    })).raise_for_status()

    # Update labels
    labelResponse = requests.get(url=f'https://api.github.com/repos/{organization}/{name}/labels', headers=githubHeaders)
    labelResponse.raise_for_status()
    repoNameLabelMap = {label['name']: label for label in labelResponse.json()}
    kibaNameLabelMap = {label['name']: label for label in KIBA_LABELS}
    toRemove = set(repoNameLabelMap.keys()) - set(kibaNameLabelMap.keys())
    if toRemove:
        logging.info(f'Removing {len(toRemove)} labels')
        for labelName in toRemove:
            requests.delete(url=f'https://api.github.com/repos/{organization}/{name}/labels/{labelName}', headers=githubHeaders).raise_for_status()
    toAdd = set(kibaNameLabelMap.keys()) - set(repoNameLabelMap.keys())
    if toAdd:
        logging.info(f'Adding {len(toAdd)} labels')
        for labelName in toAdd:
            requests.post(url=f'https://api.github.com/repos/{organization}/{name}/labels', headers=githubHeaders, data=json.dumps(kibaNameLabelMap[labelName])).raise_for_status()
    toUpdate = set(kibaNameLabelMap.keys()).intersection(set(repoNameLabelMap.keys()))
    if toUpdate:
        logging.info(f'Updating {len(toUpdate)} labels')
        for labelName in toUpdate:
            oldLabel = repoNameLabelMap[labelName]
            newLabel = kibaNameLabelMap[labelName]
            requests.patch(url=f'https://api.github.com/repos/{organization}/{name}/labels/{oldLabel["name"]}', headers=githubHeaders, data=json.dumps({
                'new_name': newLabel['name'],
                'color': newLabel['color'],
                'description': newLabel['description'],
            })).raise_for_status()

    # Update protected branches
    requests.put(url=f'https://api.github.com/repos/{organization}/{name}/branches/{primaryBranch}/protection', headers=githubHeaders, data=json.dumps({
        'required_pull_request_reviews': {
            'require_code_owner_reviews': True
        },
        'required_status_checks': {
            'strict': True,
            'contexts': []
        },
        'required_linear_history': True,
        'enforce_admins': True,
        'restrictions': {
            'users': [],
            'teams': [],
        },
    })).raise_for_status()

    # Update security settings
    requests.put(url=f'https://api.github.com/repos/{organization}/{name}/automated-security-fixes', headers=githubHeadersLokiPreview).raise_for_status()

@click.command()
@click.option('-o', '--organization', 'organization', required=True, type=str, default='krishan711')
@click.option('-n', '--name', 'name', required=True, type=str)
@click.option('-g', '--github-api-token', 'githubApiToken', required=True, type=str, default=lambda: os.environ['GITHUB_TOKEN'], show_default='GITHUB_TOKEN in your environment variables')
@click.option('-v', '--verbose', 'verbose', required=False, is_flag=True, default=False)
def run(organization: str, name: str, verbose: bool, githubApiToken: str):
    logging.basicConfig(level=logging.DEBUG if verbose else logging.INFO)
    create_github_repo(organization=organization, name=name, githubApiToken=githubApiToken)

if __name__ == '__main__':
    run()
