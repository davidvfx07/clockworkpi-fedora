#!/bin/bash

# CONTAINER_IMAGE="containers-storage:localhost/cf-uconsole-base:latest_linux_arm64"
CONTAINER_IMAGE="registry:ghcr.io/davidvfx07/cf-uconsole-base:latest"
OUTPUT_IMAGE="registry:ClockworkPi-Fedora-uConsole-Base-raw-43.raw"
IMAGE_SIZE="7GB"

pushd image-builder

sudo setenforce 0
sudo podman run --rm -it --privileged \
  --platform=linux/arm64 \
  --security-opt label=disable \
  --device /dev/loop-control \
  -e CONTAINER_IMAGE=$CONTAINER_IMAGE \
  -e OUTPUT_IMAGE=$OUTPUT_IMAGE \
  -e IMAGE_SIZE=$IMAGE_SIZE \
  -v /dev:/dev \
  -v /var/lib/containers:/var/lib/containers \
  -v $(pwd)/input:/input:ro \
  -v $(pwd)/output:/output \
  -v $(pwd)/build-rpi.sh:/build.sh \
  quay.io/fedora/fedora-bootc:latest \
  bash /build.sh
sudo setenforce 1

popd
