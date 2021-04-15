
#!/usr/bin/env bash
set -e -o pipefail

name="datadog-agent"
dockerImageName="gcr.io/datadoghq/agent"
dockerTag="7"
dockerImage="${dockerImageName}:${dockerTag}"
varsFile=~/.${name}.vars

docker pull ${dockerImageName}
docker stop ${name} || true
docker rm ${name} || true

DOCKER_CONTENT_TRUST=1
docker run \
    --name ${name} \
    --detach \
    --restart on-failure \
    --volume /var/run/docker.sock:/var/run/docker.sock:ro \
    --volume /proc/:/host/proc/:ro \
    --volume /sys/fs/cgroup/:/host/sys/fs/cgroup:ro \
    --volume /opt/datadog-agent/run:/opt/datadog-agent/run:rw \
    --env-file ${varsFile} \
    -e DD_LOGS_ENABLED=true \
    -e DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true \
    -e DD_CONTAINER_EXCLUDE="name:datadog-agent" \
    ${dockerImage}
