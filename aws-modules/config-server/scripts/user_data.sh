#!/bin/bash
set -e

# Pinned image tag — do NOT use :latest, which is mutable and can pull a build
# with mismatched Spring Boot/Spring Cloud versions (causes a startup crash loop).
# Bump this in lockstep with the Jib tag in the config-server pom.xml.
CONFIG_SERVER_IMAGE="travelhelper0h/sathishproject-config-server:2025.0.2"

# Update and install Docker + AWS CLI
yum update -y
yum install -y docker aws-cli
systemctl start docker
systemctl enable docker

# Fetch secrets from SSM Parameter Store — nothing sensitive in this script
GIT_URI=$(aws ssm get-parameter \
  --name /config-server/git_uri \
  --query 'Parameter.Value' \
  --output text \
  --region us-east-1)

ENCRYPT_KEY=$(aws ssm get-parameter \
  --name /config-server/encrypt_key \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text \
  --region us-east-1)

USERNAME=$(aws ssm get-parameter \
  --name /config-server/username \
  --query 'Parameter.Value' \
  --output text \
  --region us-east-1)

PASS=$(aws ssm get-parameter \
  --name /config-server/pass \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text \
  --region us-east-1)

# Write to root-only env file and clear variables from shell
install -m 600 /dev/null /etc/config-server.env
printf 'GIT_URI=%s\nencrypt_key=%s\nusername=%s\npass=%s\nAPP_PORT=8888\n' \
  "$GIT_URI" "$ENCRYPT_KEY" "$USERNAME" "$PASS" > /etc/config-server.env

unset GIT_URI ENCRYPT_KEY USERNAME PASS

# Pull and run the config server container
docker pull "$CONFIG_SERVER_IMAGE"

docker run -d \
  --name config-server \
  --restart unless-stopped \
  -p 8888:8888 \
  --env-file /etc/config-server.env \
  "$CONFIG_SERVER_IMAGE"
