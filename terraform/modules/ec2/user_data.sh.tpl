#!/bin/bash

set -e

apt-get update -y
apt-get upgrade -y

apt-get install -y \
  docker.io \
  docker-compose-v2 \
  git \
  curl \
  unzip \
  nginx

systemctl enable docker
systemctl start docker

usermod -aG docker ubuntu

mkdir -p /home/ubuntu/skillpulse

chown -R ubuntu:ubuntu /home/ubuntu/skillpulse

cat <<EOF >/etc/motd
=========================================
 SkillPulse ${environment} Environment
=========================================
EOF