#!/bin/bash

# Exit on error
set -e

# 1. Define Environment Variables
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=clang
export CLANG_TRIPLE=aarch64-linux-gnu-
export LD=ld.lld

# 2. Apply the configuration
echo "Applying renoir_defconfig..."
make vendor/renoir_defconfig

# 3. Sync configuration with the compiler
echo "Syncing configuration..."
make olddefconfig

# 4. Build the Kernel and Device Tree Blobs
echo "Starting build..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang CLANG_TRIPLE=aarch64-linux-gnu- LD=ld.lld -j$(nproc) Image dtbs
