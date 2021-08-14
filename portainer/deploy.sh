#!/usr/bin/env bash

echo -e "Deploying container...\n"

source .env
env CIFS_SHARE="${CIFS_SHARE}" CIFS_UN="${CIFS_UN}" CIFS_PW="${CIFS_PW}" \
docker stack deploy portainer --prune --with-registry-auth --resolve-image=always --compose-file /home/docker/portainer/portainer-agent-stack.yml

echo -e "\nComplete"
