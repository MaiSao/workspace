#!/bin/bash
set -euo pipefail

export DOCKER_BUILDKIT=0
########################################
# Configuration
########################################
DOCKER_USER="saocd"
IMAGE_NAME="bridge"

# File hoặc thư mục cần đóng gói
SOURCE_PATH="/workspace/k8s_auto"

# Tag theo ngày
TAG=$(date +%Y%m%d)

IMAGE="${DOCKER_USER}/${IMAGE_NAME}:${TAG}"
LATEST_IMAGE="${DOCKER_USER}/${IMAGE_NAME}:latest"

########################################
# Check
########################################
if [ ! -e "$SOURCE_PATH" ]; then
    echo "ERROR: $SOURCE_PATH does not exist."
    exit 1
fi

command -v docker >/dev/null || {
    echo "Docker is not installed."
    exit 1
}

########################################
# Create temporary build context
########################################
WORKDIR=$(mktemp -d)

mkdir -p "$WORKDIR/payload"

cp -a "$SOURCE_PATH" "$WORKDIR/payload/"

cat > "$WORKDIR/Dockerfile" <<EOF
FROM alpine:3.20

LABEL maintainer="${DOCKER_USER}"
LABEL description="Backup package"
LABEL build_date="$(date -Iseconds)"

COPY payload /payload

WORKDIR /payload

CMD ["sh"]
EOF

########################################
# Build
########################################
echo "==> Building image ${IMAGE}"

docker build -t "${IMAGE}" "$WORKDIR"

########################################
# Tag latest
########################################
docker tag "${IMAGE}" "${LATEST_IMAGE}"

########################################
# Push
########################################
echo "==> Pushing ${IMAGE}"
docker push "${IMAGE}"

echo "==> Pushing ${LATEST_IMAGE}"
docker push "${LATEST_IMAGE}"

########################################
# Cleanup
########################################
rm -rf "$WORKDIR"

echo
echo "======================================"
echo "Completed successfully"
echo "Image:"
echo "  ${IMAGE}"
echo "  ${LATEST_IMAGE}"
echo "======================================"