#!/bin/bash

# Do not set the set -x flag
# This will cause passwords to be printed to the console and log files.

# USER-DATA SHIPPED TO LOGS
exec > >(tee /var/log/user-data.log|logger -t user-data ) 2>&1
echo "Running user_data script ($0)"
date '+%Y-%m-%d %H:%M:%S'

umask 022

# INSTALLING UTILITIES
sudo apt-get update
sudo apt-get install awscli -y
sudo apt-get install curl -y

# logic to attach EBS volume
EC2_INSTANCE_ID=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id || die \"wget instance-id has failed: $?\")
EC2_AVAIL_ZONE=$(wget -q -O - http://169.254.169.254/latest/meta-data/placement/availability-zone || die \"wget availability-zone has failed: $?\")
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
DIRECTORY=/steamcmd/rust

#############
# EBS VOLUME
#
# note: /dev/sdh => /dev/xvdh
# see: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html
#############

# wait for EBS volume to attach
DATA_STATE="unknown"
until [ $DATA_STATE == "attached" ]; do
	DATA_STATE=$(aws ec2 describe-volumes \
	    --region $${EC2_REGION} \
	    --filters \
	        Name=attachment.instance-id,Values=$${EC2_INSTANCE_ID} \
	        Name=attachment.device,Values=/dev/sdh \
	    --query Volumes[].Attachments[].State \
	    --output text)
	echo 'waiting for volume...'
	sleep 5
done

echo 'EBS volume attached!'

# Format /dev/xvdh if it does not contain a partition yet
if [ "$(file -b -s /dev/xvdh)" == "data" ]; then
  mkfs -t ext4 /dev/xvdh
fi

# Create the Rust directory on our EC2 instance if it doesn't exist
if [ ! -d "$DIRECTORY" ]; then
  mkdir -p $DIRECTORY
fi

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

cat > /rust.env <<- "EOF"
RUST_SERVER_STARTUP_ARGUMENTS="-batchmode -load -logfile /dev/stdout +server.secure 1"
RUST_SERVER_IDENTITY="Fragtopia"
RUST_SERVER_SEED="4983"
RUST_SERVER_NAME="Fragtopia Rust"
RUST_SERVER_DESCRIPTION="Fragtopia Rust"
RUST_RCON_PASSWORD="SuperSecurePassword"

RUST_SERVER_WORLDSIZE="2000"
RUST_SERVER_MAXPLAYERS="100"
RUST_SERVER_DESCRIPTION="Fragtopia: Carebear-ish"
EOF

# START THE RUST CONTAINER.  DOWNLOADS LATEST RUST-SERVER IMAGE FROM DOCKER HUB
#docker run --name rust-server didstopia/rust-server
docker run --name rust-server -d -p 28015:28015 -p 28015:28015/udp -p 28016:28016 -p 8080:8080 -v /rust:/steamcmd/rust --env-file /rust.env didstopia/rust-server
