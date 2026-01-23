#!/usr/bin/env bash
set -e -o pipefail

docker stop frpc || true
docker rm frpc || true

rm $(pwd)/frpc.toml
touch $(pwd)/frpc.toml
echo """
serverAddr = \"52.211.242.27\"
serverPort = 7123
auth.method = \"token\"
auth.token = \"3ifh389uyf92hc9j2f,h-fh2-54m9fh-2fhx-2hf-234hfx2hf-2f\"
transport.tls.enable = false

[[proxies]]
name = \"images\"
type = \"http\"
subdomain = \"images\"
localIP = \"127.0.0.1\"
localPort = 18463
""" > $(pwd)/frpc.toml

docker run \
    --name frpc \
    --detach \
    --publish-all \
    --network=host \
    --restart=always \
    --volume $(pwd)/frpc.toml:/etc/frp/frpc.toml \
    fatedier/frpc:v0.59.0 -c /etc/frp/frpc.toml
docker logs -f frpc
