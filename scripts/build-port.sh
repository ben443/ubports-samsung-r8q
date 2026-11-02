#!/bin/bash
set -euo pipefail

cd -- "$(dirname -- "$(realpath -- "$0")")/.."
source ./deviceinfo

cache=.build
output=out
while [ "$#" -gt 0 ]; do
    case "$1" in
        -b|-o)
            if [ "$#" -lt 2 ] || [ -z "$2" ]; then
                echo "Missing path for $1" >&2
                exit 1
            fi
            if [ "$1" = -b ]; then cache=$2; else output=$2; fi
            shift 2
            ;;
        *)
            echo "Usage: ./build.sh [-b build-directory] [-o output-directory]" >&2
            exit 1
            ;;
    esac
done

for tool in clang-14 make git curl python3 bc bison flex cpio openssl \
    llvm-ar-14 llvm-strip-14 tar xz; do
    if ! command -v "$tool" >/dev/null; then
        echo "Missing build dependency: $tool (see .gitlab-ci.yml)" >&2
        exit 1
    fi
done
export PATH="$(dirname -- "$(realpath -- "$(command -v clang-14)")"):$PATH"

mkdir -p "$cache" "$output"
cache=$(realpath -- "$cache")
output=$(realpath -- "$output")
kernel="$cache/kernel"
objects="$cache/KERNEL_OBJ"
if [ ! -d "$kernel" ]; then
    git clone --no-checkout --depth 1 --branch "$deviceinfo_kernel_source_branch" \
        "$deviceinfo_kernel_source" "$kernel"
fi
if ! git -C "$kernel" cat-file -e "$deviceinfo_kernel_source_revision^{commit}" 2>/dev/null; then
    git -C "$kernel" fetch --depth 1 origin "$deviceinfo_kernel_source_revision"
fi
git -C "$kernel" checkout --detach "$deviceinfo_kernel_source_revision"
git -C "$kernel" submodule update --init --recursive --depth 1

staging=$(mktemp -d "$cache/staging.XXXXXXXX")
mkdir -p "$staging/system" "$staging/partitions"
make_args=( -C "$kernel" "O=$objects" ARCH=arm64 LLVM=1 LLVM_IAS=1
    CROSS_COMPILE=aarch64-linux-gnu- )
make "${make_args[@]}" "$deviceinfo_kernel_defconfig"
make "${make_args[@]}" -j"$(nproc)" Image Image.gz dtbs modules
make "${make_args[@]}" INSTALL_MOD_STRIP=1 \
    "INSTALL_MOD_PATH=$staging/system" modules_install

ramdisk="$cache/halium-boot-ramdisk.img"
if [ ! -s "$ramdisk" ]; then
    curl --fail --location --retry 3 \
        https://github.com/Halium/initramfs-tools-halium/releases/download/dynparts/initrd.img-touch-arm64 \
        --output "$ramdisk.download"
    mv -- "$ramdisk.download" "$ramdisk"
fi
if [ ! -d "$cache/avb" ]; then
    git clone --depth 1 --branch lineage-20.0 \
        https://github.com/LineageOS/android_external_avb.git "$cache/avb"
fi
if [ ! -d "$cache/mkbootimg" ]; then
    git clone --depth 1 --branch lineage-19.1 \
        https://github.com/LineageOS/android_system_tools_mkbootimg.git "$cache/mkbootimg"
fi

boot="$staging/partitions/boot.img"
python3 "$cache/mkbootimg/mkbootimg.py" \
    --kernel "$objects/arch/arm64/boot/$deviceinfo_kernel_image_name" \
    --ramdisk "$ramdisk" --dtb "$deviceinfo_bootimg_prebuilt_dtb" \
    --header_version "$deviceinfo_bootimg_header_version" \
    --base "$deviceinfo_flash_offset_base" \
    --kernel_offset "$deviceinfo_flash_offset_kernel" \
    --ramdisk_offset "$deviceinfo_flash_offset_ramdisk" \
    --second_offset "$deviceinfo_flash_offset_second" \
    --tags_offset "$deviceinfo_flash_offset_tags" \
    --dtb_offset "$deviceinfo_flash_offset_dtb" \
    --pagesize "$deviceinfo_flash_pagesize" --board "$deviceinfo_bootimg_board" \
    --cmdline "$deviceinfo_kernel_cmdline" \
    --os_version "$deviceinfo_bootimg_os_version" \
    --os_patch_level "$deviceinfo_bootimg_os_patch_level" -o "$boot"
python3 "$cache/avb/avbtool.py" add_hash_footer --image "$boot" \
    --partition_name boot --partition_size "$deviceinfo_bootimg_partition_size"
python3 "$cache/avb/avbtool.py" verify_image --image "$boot"

cp -a overlay/. "$staging/"
cp -- "$boot" "$output/boot.img"
./build/build-tarball-mainline.sh "$deviceinfo_codename" "$output" "$staging"
./build/build-tarball-mainline.sh "$deviceinfo_codename" "$output" "$staging" true
printf 'Built device adaptation in %s (staging retained at %s)\n' "$output" "$staging"
