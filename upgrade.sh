#!/bin/bash

cd /opt/VoteServer
git stash
git pull

chmod +x ./upgrade.sh

docker compose pull
docker compose stop
docker compose up -d
