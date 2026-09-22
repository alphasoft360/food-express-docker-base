#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
echo "Host LAN IP: $HOST_LAN_IP"
docker ps -a --filter label=com.docker.compose.project=enatega --format 'table {{.Label "com.docker.compose.service"}}\t{{.Status}}\t{{.Ports}}'
