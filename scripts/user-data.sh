#!/bin/bash

apt-get update

# Install prerequisites
apt-get install -y ca-certificates curl gnupg git

# Create directory for keyrings
install -m 0755 -d /etc/apt/keyrings

# Download and install Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add ubuntu user to docker group to run docker without sudo
usermod -aG docker ubuntu

systemctl enable docker
systemctl start docker

mkdir -p /home/ubuntu/workspace

cd /home/ubuntu/workspace

git clone -b Continuous_Deployment_Usage https://github.com/morAroesti/entryTracker.git

chown -R ubuntu:ubuntu /home/ubuntu/workspace