#!/bin/bash

# Do not set the set -x flag
# This will cause passwords to be printed to the console and log files.

# USER-DATA SHIPPED TO LOGS
exec > >(tee /var/log/user-data.log|logger -t user-data ) 2>&1
echo "Running user_data script ($0)"
date '+%Y-%m-%d %H:%M:%S'

umask 022

# INSTALLING CURL
sudo apt-get install curl -y

# INSTALLING DOCKER
curl -fsSL https://get.docker.com/ | sh

# CONFIGURE FIREWALL USING UFW
sudo apt-get install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 28015
sudo ufw allow 28015/udp
sudo ufw allow 28016
sudo ufw allow 8080
sudo ufw enable

# START THE RUST CONTAINER.  DOWNLOADS LATEST RUST-SERVER IMAGE FROM DOCKER HUB
docker run --name rust-server didstopia/rust-server
