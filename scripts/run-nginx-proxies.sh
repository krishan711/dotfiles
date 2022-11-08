#!/usr/bin/env bash
set -e -o pipefail

name="proxy"
dockerImageName="nginxproxy/nginx-proxy"
dockerTag="latest"
dockerImage="${dockerImageName}:${dockerTag}"

docker pull ${dockerImageName}
docker stop ${name} || true
docker rm ${name} || true
docker run \
    --name ${name} \
    --detach \
    --publish 80:80 \
    --publish 443:443 \
    --restart on-failure \
    --volume /etc/nginx/certs \
    --volume /etc/nginx/vhost.d \
    --volume /usr/share/nginx/html \
    --volume /var/run/docker.sock:/tmp/docker.sock:ro \
    --volume $(pwd)/nginx-custom.conf:/etc/nginx/conf.d/custom.conf \
    ${dockerImage}

proxyContainerName=${name}
name="proxy-letsencrypt"
dockerImageName='jrcs/letsencrypt-nginx-proxy-companion'
dockerTag="latest"
dockerImage="${dockerImageName}:${dockerTag}"

docker pull ${dockerImageName}
docker stop ${name} || true
docker rm ${name} || true
docker run \
    --name ${name} \
    --detach \
    --restart on-failure \
    --volumes-from ${proxyContainerName} \
    --volume /var/run/docker.sock:/var/run/docker.sock:ro \
    ${dockerImage}
