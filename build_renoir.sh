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
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang CLANG_TRIPLE=aarch64-linux-gnu- LD=ld.lld vendor/renoir_defconfig

# 3. Sync configuration with the compiler
echo "Syncing configuration..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang CLANG_TRIPLE=aarch64-linux-gnu- LD=ld.lld olddefconfig

# 4. Build the Kernel, Device Tree Blobs, and Modules
echo "Starting build..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang CLANG_TRIPLE=aarch64-linux-gnu- LD=ld.lld -j$(nproc) Image dtbs modules

# 5. Package with AnyKernel3
echo "Packaging with AnyKernel3..."
AK3_DIR="AnyKernel3"
BUILD_ARTIFACTS_DIR="arch/arm64/boot"
DTBO_DIR="${BUILD_ARTIFACTS_DIR}/dts/vendor/qcom"

# Copy kernel image
cp "${BUILD_ARTIFACTS_DIR}/Image" "${AK3_DIR}/"

# Copy renoir DTBO
if [ -f "${DTBO_DIR}/renoir-sm7350-overlay.dtbo" ]; then
    cp "${DTBO_DIR}/renoir-sm7350-overlay.dtbo" "${AK3_DIR}/dtbo.img"
fi

# Create flashable zip
cd "${AK3_DIR}"
zip -r9 "../renoir-kernel.zip" * -x .git README.md *placeholder
cd ..

echo "Build and packaging complete: renoir-kernel.zip"
