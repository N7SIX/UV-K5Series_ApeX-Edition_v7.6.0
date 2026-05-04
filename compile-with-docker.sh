#!/bin/sh

# Cross-platform Docker volume mount fix
IMAGE_NAME="uvk5"
# Detect Windows and convert $PWD to Windows-style path for Docker
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        # Git Bash/MinGW/MSYS/WSL: convert /c/Users/... to C:/Users/...
        WIN_PWD=$(pwd -W 2>/dev/null || cygpath -w "$(pwd)")
        DOCKER_BUILD_PATH="${WIN_PWD}/build"
        ;;
    *)
        DOCKER_BUILD_PATH="${PWD}/build"
        ;;
esac
FIRMWARE_DIR="${PWD}/build/ApeX"
# Default: Alpine 3.21; you can pass BASE=alpine:3.22 / alpine:3.19 / alpine:edge
BASE="${BASE:-alpine:3.22}"
CMD=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')

# --- Derive the Alpine tag from BASE ---
case "$BASE" in
  alpine:*)  ALPINE_TAG="${BASE#alpine:}";;
  alpine)    ALPINE_TAG="3.22";;  # fallback if no tag provided
  *)
    echo "❌ BASE must be 'alpine:<tag>' (e.g., alpine:3.21, alpine:edge). Got: '$BASE'"
    exit 1
    ;;
esac

usage() {
    echo "Usage: BASE=alpine:<tag> $0 {clean|ApeX|apex}"
    echo "Examples: BASE=alpine:3.22 … | BASE=alpine:3.21 … | BASE=alpine:3.19 … | BASE=alpine:edge …"
}

prepare_build() {
    # Create firmware output directory if it doesn't exist
    mkdir -p "$FIRMWARE_DIR"

    # Clean previously compiled firmware files
    rm -f "$FIRMWARE_DIR"/*

    # Clean up old Docker artifacts
    echo "🧽 Cleaning up old Docker artifacts..."
    docker system prune -f --volumes >/dev/null 2>&1 || true

    # Always rebuild the Docker image to ensure latest code changes
    echo "⚙️ Rebuilding Docker image '$IMAGE_NAME' (base=${BASE})..."
    docker rmi "$IMAGE_NAME" 2>/dev/null || true
    if ! docker build --pull --build-arg "ALPINE_TAG=${ALPINE_TAG}" -t "$IMAGE_NAME" .; then
        echo "❌ Failed to build docker image"
        exit 1
    fi
}

# -------------------- CLEAN ALL ---------------------

clean() {
    echo "🧽 Cleaning all"
    docker rmi "$IMAGE_NAME" 2>/dev/null || true
    docker buildx prune -f || true
    # Optional: if you use buildx history tooling
    if command -v docker >/dev/null 2>&1 && docker buildx help history >/dev/null 2>&1; then
      docker buildx history ls | awk 'NR>1 {print $1}' | xargs docker buildx history rm || true
    fi
    make clean || true
}

# ------------------ BUILD VARIANTS ------------------
ApeX() {
    prepare_build
    echo "🦾 Compiling ApeX..."
    docker run -v "$DOCKER_BUILD_PATH:/app/build" "$IMAGE_NAME" bash -c "\
        cd /app && make -s \
        EDITION_STRING=ApeX \
        TARGET=ApeX"
}
# ------------------ MENU ------------------

case "$CMD" in
    clean) clean ;;
    apex) ApeX ;;
    *)
        usage
        exit 1
        ;;
esac
