# EFI loader choices for a fresh Orange Pi 5 Plus installation

This is a source review for design decisions, not a boot test. The software baseline is nixpkgs
unstable `6510408d147d8c5e6d76043e899e9251756f6a75`, systemd 261.3, Limine 12.9.3, and RK3588 EDK2
source `be4d361435ef5727e72d0c52e2d457d7ae465c2d`. No bootloader, firmware, disk, key slot, or
running host was changed.

## Recommendation

For a fresh EFI installation that is intended to move back into nix-config, prefer systemd-boot with
the firmware's compatible Mainline DT and explicit `installDeviceTree = false`. Limine is a real
aarch64/Linux candidate, not an x86-only bootloader, but its native Linux handoff introduces another
path to validate on RK3588. Keep the loader choice separate from the recovery policy and from the
installer media's loader.

| Property                      | systemd-boot                                                                                                                                                       | Limine                                                                                                                                   |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| aarch64 support               | Upstream UEFI manager starts an EFI-stub Linux image.                                                                                                              | NixOS module allows aarch64 and package builds `BOOTAA64.EFI`; Linux uses a native ARM64 handoff.                                        |
| Kernel/initrd generations     | NixOS builder creates separate boot entries and copied kernel/initrd paths; configuration limit and stale-file cleanup are supported.                              | NixOS installer creates Linux entries and copies kernel/initrd files; `maxGenerations` limits retained entries.                          |
| Firmware DT                   | Preserved when no entry DT override is generated.                                                                                                                  | Without `dtb_path` or `global_dtb`, upstream code copies the firmware's EFI DT table and adds Linux handoff properties.                  |
| Critical configuration detail | NixOS `installDeviceTree` defaults to `hardware.deviceTree.enable && name != null`; the board's named DT therefore enables an override unless explicitly disabled. | NixOS-generated Linux entries contain no DT field. Extra configuration may still supply an override, so inspect the actual config.       |
| Manual rollback               | Select an older retained NixOS entry.                                                                                                                              | Select an older retained NixOS entry.                                                                                                    |
| Automatic assessment          | NixOS exposes optional `bootCounting.enable`, disabled by default, with three attempts by default.                                                                 | This review did not establish equivalent NixOS health assessment integration. Do not infer automatic rollback from generation retention. |

[NixOS systemd-boot module](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/nixos/modules/system/boot/loader/systemd-boot/systemd-boot.nix),
[systemd-boot builder](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/nixos/modules/system/boot/loader/systemd-boot/systemd-boot-builder.py),
[Limine module](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/nixos/modules/system/boot/loader/limine/limine.nix),
[Limine installer](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/nixos/modules/system/boot/loader/limine/limine-install.py).

## ARM64 handoff is not identical

Limine 12.9.3's `linux_risc.c` is explicitly compiled for aarch64. It checks the ARM64 Linux Image
header, places kernel/initrd within the ARM64 constraints, obtains a required DT, prepares Linux and
EFI metadata, exits boot services, and jumps to Linux. It is not simply loading the kernel as an EFI
application. Its common `get_device_tree_blob` function checks entry `dtb_path`, then `global_dtb`,
then the firmware `EFI_DTB_TABLE_GUID`, copying the firmware DT if no file override exists. These
are positive source facts; they do not prove RK3588 cold boot, PCIe, NVMe, USB unlock or KVM
operation.

[Limine ARM64/Linux implementation](https://github.com/Limine-Bootloader/Limine/blob/v12.9.3/common/protos/linux_risc.c),
[DT source selection](https://github.com/Limine-Bootloader/Limine/blob/v12.9.3/common/lib/misc.c#L216),
[configuration documentation](https://github.com/Limine-Bootloader/Limine/blob/v12.9.3/CONFIG.md),
[nixpkgs package](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/pkgs/by-name/li/limine/package.nix).

systemd-boot instead starts configured EFI images, requiring Linux EFI stub support. Its DT install
code calls `EFI_DT_FIXUP_PROTOCOL` when firmware exposes it, and proceeds without fixups when the
protocol is unavailable. Therefore a blanket claim that every systemd-boot DT override bypasses
firmware fixups is inaccurate. However, the reviewed RK3588 `FdtPlatformDxe` uses its own internal
platform-fixup and override mechanisms; this driver does not expose that protocol. Its presence in
an actual firmware build was not established. Retaining the already prepared firmware DT avoids
making this optional protocol an unverified prerequisite.

[systemd-boot behavior](https://github.com/systemd/systemd/blob/v261.3/docs/BOOT.md),
[DT install/fixup implementation](https://github.com/systemd/systemd/blob/v261.3/src/boot/devicetree.c),
[RK3588 firmware DT driver](https://github.com/edk2-porting/edk2-rk3588/blob/be4d361435ef5727e72d0c52e2d457d7ae465c2d/edk2-rockchip/Silicon/Rockchip/RK3588/Drivers/FdtPlatformDxe/FdtPlatformDxe.c).

## EFI installation and recovery

NixOS systemd-boot uses bootctl installation/update and passes `--variables=no` when
`boot.loader.efi.canTouchEfiVariables` is false. Limine has its own `efiInstallAsRemovable` choice,
writes the aarch64 fallback executable, and skips NVRAM entry creation in removable mode. Both need
the firmware to discover their EFI executable; U-Boot is relevant only when its tested EFI
environment actually provides the required firmware interface and compatible DT. Native extlinux
boot is a different design. Neither loader removes the requirement to test the exact board/firmware
boot path.

Preserve an unencrypted ESP and keep LUKS unlock in the initrd. Fresh installation must separately
enroll the recovery passphrase: selecting a loader does not create a LUKS password slot. Retaining
generations provides manual kernel/initrd rollback; automatic boot assessment is a separate policy
and generic boot completion is not proof that Ethernet or a MicroVM is healthy. A broken kernel that
hangs also needs a reboot mechanism before any next-attempt counter can make progress.

[bootctl manual](https://www.freedesktop.org/software/systemd/man/latest/bootctl.html),
[automatic boot assessment](https://github.com/systemd/systemd/blob/v261.3/docs/AUTOMATIC_BOOT_ASSESSMENT.md),
[NixOS boot-counting option](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/nixos/modules/system/boot/loader/systemd-boot/systemd-boot.nix#L421).

The official aarch64 installer may itself use GRUB; that does not constrain the installed host to
GRUB. First confirm that the selected installer boots through the intended firmware and sees the
installation hardware. Then validate the installed loader, current and previous generations,
password recovery without the USB key, and USB repair media. This review does not authorize or
perform those actions.
