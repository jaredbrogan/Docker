#!/usr/bin/env bash

echo -e "Deploying container...\n"

source .env
env STACK_DOMAIN="${STACK_DOMAIN}" STACK_COLOR="${STACK_COLOR}" \
docker stack deploy httpd --prune --with-registry-auth --resolve-image=always --compose-file /home/docker/httpd/docker-compose.yml

echo -e "\nComplete"
