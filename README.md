# Ubuntu Touch for Samsung Galaxy S20 FE (r8q)

Experimental Halium 11 adaptation for the Snapdragon device, not the Exynos
Galaxy S20 FE. The kernel, boot image and device adaptation tarballs have been
built successfully. A complete Ubuntu Touch rootfs installation and boot on
hardware have not been verified. Booting Droidian does not by itself establish
compatibility with this Ubuntu Touch userspace.

## Building

The kernel build targets Ubuntu 22.04 on x86_64 with Clang/LLVM 14, matching the
supplied Droidian kernel's successful CI configuration. Install the dependencies
listed in the `build` job in `.gitlab-ci.yml`, then run:

```sh
./build.sh
```

The wrapper downloads the Halium 11 adaptation build tools from the GitHub fork
at `ben443/halium-generic-adaptation-build-tools` for tarball and rootfs packaging.
`scripts/build-port.sh` builds the kernel with the host LLVM 14 tools, including
its pinned Lindroid submodule, and downloads the Halium initramfs, Python 3 AVB
tools (`lineage-20.0`), and mkbootimg (`lineage-19.1`) from GitHub. No Android
compiler download from googlesource is needed.
Network access to those upstream sources is required. The adaptation output is
`out/boot.img`, `out/device_r8q.tar.xz` and `out/device_r8q_usrmerge.tar.xz`, not a
complete Ubuntu Touch installation. The boot image is checked with AVB before
packaging; its footer is unsigned and does not provide production verified boot.
The
`devel-flashable` GitLab job combines it with an Ubuntu Touch rootfs and generic
Android image.

Use `./build.sh --fetch-tools-only` to fetch the tools without starting a build,
or `./build.sh -b .build -o out` to retain downloads and intermediate build files
between attempts.

The selected kernel is `ben443/android_kernel_samsung_r8q_droidian`, branch
`Halium-latest`, pinned to `8f87aa3709273c6b14e8c44e20b486ae84efff1f`.
It uses `vendor/samsung-rq8-halium_defconfig` (the `rq8` spelling is upstream).
Upstream CI reports that revision built successfully with LLVM 14; that does not
verify this port's complete boot image or its compatibility with installed vendor
firmware. Boot header v2 and the checked-in DTB are retained pending hardware
validation. Build intermediates are retained in `.build/`, including staging
directories; use a different `-b` directory when changing kernel sources.

No recovery image is generated. The previous recovery ramdisk was for a
Galaxy Tab S7 Plus, not r8q. Do not substitute tablet recovery images or flash
the outputs until the firmware, partition layout, and boot image compatibility
have been checked against the actual handset.

## Uploaded Droidian adaptation

The uploaded files were inspected without installing them:

| Upload | Contents |
| --- | --- |
| `adaptation-samsung-s20fe-configs_0.0.1-1_arm64.deb` | Documentation only; no device configuration payload. |
| `adaptation-samsung-s20fe_0.0.1-1_arm64.deb` | Droidian systemd services, udev permissions, and vendor sensor/camera overrides. No kernel or boot image. |
| `adaptation-samsung-s20fe-droidian-halium-13.deb` | A ZIP source archive, despite the `.deb` extension; not an installable Debian package. |

These are from the
[Mathew Dennis S20 FE adaptation](https://github.com/mathew-dennis/adaptation-samsung-s20fe),
whose included copyright file declares BSD-3-Clause.

The touchscreen workaround enables `/sys/class/sec/tsp/input/enabled` after
the compositor starts. It is implemented here as an Upstart job after Android
and LightDM start, retaining the upstream five-second delay. A missing or
unwritable sysfs node fails the job rather than reporting success.

The other Droidian settings are not installed automatically:

- Phosh compositor options and systemd services do not configure Ubuntu Touch's
  Unity8/Upstart session.
- The audio bind mount references Droidian-specific library paths. Its wrapper
  must be verified in the target Android image before adapting it.
- The sensor binary and VINTF/camera overrides require matching Android vendor
  interfaces. The source archive targets Halium 13; this port targets Halium 11.
- Disabling Bluetooth or journaling is not required for a build and would
  remove functionality or diagnostics.

Further integration requires a matching kernel, Android vendor firmware and
generic Halium image. These adaptation packages do not provide those components.

## Additional port reference

The supplied [Ubtouch-r8q repository](https://github.com/ben443/Ubtouch-r8q/tree/halium-11.0)
identifies another kernel candidate:
`ben443/aosp_kernel_samsung_sm8250`, branch `Arrow-13.0-new`, with
`vendor/afaneh_r8q_defconfig vendor/halium.config`. Both configuration files
exist, and the latter enables Halium namespaces, devtmpfs, and other features.
This is a candidate for further kernel validation, not a verified replacement
for this port's kernel.

That repository also contains Fold 3 (`q2q`) display, telephony and input
overlays, an SM8350 command-line identifier, boot header v3, and differing Halium
11/12 build settings. These are not evidence of the r8q handset's boot format
or firmware compatibility and are not copied here. Its GitHub build-tools fork
does provide an accessible Halium 11 branch, now used consistently by the local
wrapper and GitLab packaging jobs.
