#!/bin/bash/

# Installs docker
echo "Installing Docker"

sudo apt-get update
 
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
    
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io

# Enables Docker to run without sudo
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

sudo systemctl enable docker.service
sudo systemctl enable containerd.service

echo "docker was installed"




# Install docker-compose
echo "Installing docker-compose ..."

DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.4.1/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose

chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

echo "docker-compose was installed"



# Creates directories required for nginxproxy
echo "Setting up directories for the proxyserver"
mkdir -p /opt/conf
mkdir -p /opt/vhost
mkdir -p /opt/html
mkdir -p /opt/dhparam
mkdir -p /opt/certs
mkdir -p /opt/acme


# Downloads git repo
echo "Downloads VoteServer project"
cd /opt

git clone https://git.smkid.dk/Harcker/VoteServer.git

cd VoteServer

chmod +x ./upgrade.sh

# Runs the app
docker compose pull
echo "Starting server"
docker compose up -d
