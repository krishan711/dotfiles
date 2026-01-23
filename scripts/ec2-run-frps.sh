#!/usr/bin/env bash
set -e -o pipefail

docker stop frps || true
docker rm frps || true

touch $(pwd)/frps.toml
echo """
vhostHTTPPort = 7123
bindPort = 7123
subDomainHost = \"krishali.com\"
auth.method = \"token\"
auth.token = \"3ifh389uyf92hc9j2f,h-fh2-54m9fh-2fhx-2hf-234hfx2hf-2f\"
""" > $(pwd)/frps.toml

docker run \
    --name frps \
    --detach \
    --publish 7123:7123 \
    --restart=always \
    --volume $(pwd)/frps.toml:/etc/frp/frps.toml \
    --env VIRTUAL_HOST=images.krishali.com \
    --env LETSENCRYPT_HOST=images.krishali.com \
    fatedier/frps:v0.59.0 -c /etc/frp/frps.toml
docker logs -f frps
