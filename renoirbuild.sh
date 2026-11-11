#!/usr/bin/env bash
#
# renoirbuild.sh - Standalone Kernel Build Script for Xiaomi Mi 11 Lite 5G (renoir)
# Cherrish Kernel 5.4.302 with KernelSU-Next & SuSFS
# Author: Failedmush
#

set -e

KERNEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${KERNEL_DIR}/out"
AK3_DIR="${KERNEL_DIR}/anykernel"
ZIP_DATE="$(date +%Y%m%d_%H%M%S)"
ZIP_NAME="Cherrish-Kernel-Renoir-5.4.302-${ZIP_DATE}.zip"
ZIP_PATH="${KERNEL_DIR}/${ZIP_NAME}"

# Detect Clang Toolchain
if [ -n "${CLANG_DIR}" ] && [ -d "${CLANG_DIR}/bin" ]; then
    echo "[*] Using custom Clang toolchain: ${CLANG_DIR}"
    CLANG_BIN="${CLANG_DIR}/bin"
elif [ -d "${KERNEL_DIR}/../../../prebuilts/clang/host/linux-x86/clang-r563880c/bin" ]; then
    echo "[*] Using Android prebuilt Clang toolchain (r563880c)"
    CLANG_BIN="$(cd "${KERNEL_DIR}/../../../prebuilts/clang/host/linux-x86/clang-r563880c/bin" && pwd)"
elif which clang >/dev/null 2>&1; then
    echo "[*] Using system Clang toolchain from PATH"
    CLANG_BIN="$(dirname "$(which clang)")"
else
    echo "[-] Error: No Clang compiler found!"
    echo "    Please set CLANG_DIR=/path/to/clang before running this script."
    exit 1
fi

export PATH="${CLANG_BIN}:${PATH}"
export ARCH=arm64
export SUBARCH=arm64
export CC=clang
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
export LLVM=1
export LLVM_IAS=1

BUILD_FLAGS=(
    ARCH=arm64
    CC=clang
    LLVM=1
    LLVM_IAS=1
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
    O="${OUT_DIR}"
)

THREAD=$(nproc --all)

echo "=========================================================="
echo " Cherrish Kernel Standalone Build for Mi 11 Lite 5G"
echo " Kernel Version: Linux 5.4.302"
echo " Compiler:       $("${CLANG_BIN}/clang" --version | head -n1)"
echo " CPU Threads:    ${THREAD}"
echo "=========================================================="

mkdir -p "${OUT_DIR}"

echo "[*] Generating .config from vendor/renoir_defconfig..."
make "${BUILD_FLAGS[@]}" vendor/renoir_defconfig
echo "[*] Compiling Kernel Image, Device Trees & Modules..."
make -j${THREAD} "${BUILD_FLAGS[@]}" Image dtbs modules
echo "[*] Installing modules to temporary directory..."
rm -rf "${OUT_DIR}/modules_temp"
make -j${THREAD} "${BUILD_FLAGS[@]}" INSTALL_MOD_STRIP=1 modules_install INSTALL_MOD_PATH="${OUT_DIR}/modules_temp"

echo "[*] Generating dtbo.img..."
python3 "${KERNEL_DIR}/scripts/mkdtboimg.py" create "${OUT_DIR}/dtbo.img" --page_size=4096 \
    $(find "${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom" -name "*.dtbo")

echo "[*] Generating dtb..."
find "${OUT_DIR}/arch/arm64/boot/dts/vendor/qcom" -name "*.dtb" -exec cat {} + > "${OUT_DIR}/dtb"

echo "[*] Populating AnyKernel3 package..."
mkdir -p "${AK3_DIR}/modules/vendor/lib/modules"
rm -f "${AK3_DIR}/Image" "${AK3_DIR}/dtb" "${AK3_DIR}/dtbo.img"
rm -f "${AK3_DIR}/modules/vendor/lib/modules/"*.ko

cp "${OUT_DIR}/arch/arm64/boot/Image" "${AK3_DIR}/Image"
cp "${OUT_DIR}/dtb" "${AK3_DIR}/dtb"
cp "${OUT_DIR}/dtbo.img" "${AK3_DIR}/dtbo.img"

find "${OUT_DIR}/modules_temp" -name "*.ko" -exec cp {} "${AK3_DIR}/modules/vendor/lib/modules/" \;
find "${AK3_DIR}/modules" -name "*.ko" -exec "${CLANG_BIN}/llvm-strip" --strip-debug {} + 2>/dev/null || true

MODULE_COUNT=$(ls -1 "${AK3_DIR}/modules/vendor/lib/modules/"*.ko 2>/dev/null | wc -l)
echo "[*] Successfully copied ${MODULE_COUNT} matching kernel modules into AnyKernel3."

echo "[*] Creating flashable zip..."
cd "${AK3_DIR}"
zip -r9 "${ZIP_PATH}" * -x "*.git*" "modules/vendor/lib/modules/.gitkeep"

echo "=========================================================="
echo " BUILD SUCCESSFUL!"
echo " Flashable Zip: ${ZIP_PATH}"
echo " File Size:     $(du -h "${ZIP_PATH}" | cut -f1)"
echo "=========================================================="
