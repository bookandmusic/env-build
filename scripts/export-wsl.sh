#!/bin/bash
set -eo pipefail

IMAGE_NAME="${1:-ubuntu-dev-wsl:latest}"
OUTPUT_FILE="${2:-ubuntu-dev-wsl.tar}"

CONTAINER_ID=$(docker create "${IMAGE_NAME}" /bin/true)
docker export "${CONTAINER_ID}" -o "${OUTPUT_FILE}"
docker rm "${CONTAINER_ID}"

echo "Exported: ${OUTPUT_FILE}"
echo "Import:   wsl --import UbuntuDev <install-path> ${OUTPUT_FILE}"
