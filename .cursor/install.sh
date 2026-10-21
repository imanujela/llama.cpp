#!/usr/bin/env bash
# Build the unified llama binary and refresh the skills checkout.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

export DEBIAN_FRONTEND=noninteractive
if [ ! -f /usr/include/openssl/ssl.h ]; then
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends libssl-dev
fi

jobs="$(nproc)"
if [ "$jobs" -gt 2 ]; then
    jobs=2
fi

# clang is the default c++ here and does not see libstdc++. Use gcc.
cache=build/CMakeCache.txt
if [ -f "$cache" ] && ! grep -q 'CMAKE_CXX_COMPILER:.*=/usr/bin/g++' "$cache"; then
    rm -rf build
fi

cmake -B build \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=g++ \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_HTML=OFF \
    -DLLAMA_BUILD_APP=ON

cmake --build build --config Release -j "$jobs" --target llama-app

sudo install -m 755 build/bin/llama /usr/local/bin/llama
llama version

skills=""
for candidate in \
    /agent/repos/skills \
    /workspace/skills \
    /workspace/repos/skills \
    "$(dirname "$root")/skills"
do
    if [ -f "$candidate/package-lock.json" ]; then
        skills="$candidate"
        break
    fi
done

if [ -z "$skills" ]; then
    skills="$(find /agent /workspace /home/ubuntu /opt -maxdepth 5 -type f -path '*/skills/package-lock.json' -print -quit 2>/dev/null || true)"
    if [ -n "$skills" ]; then
        skills="$(dirname "$skills")"
    fi
fi

if [ -z "$skills" ]; then
    echo "skills checkout not found" >&2
    exit 1
fi

npm ci --prefix "$skills"
