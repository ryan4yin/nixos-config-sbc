# Orange Pi 5 Plus fresh installation and recovery

This procedure applies to `rakushun` first, then `suzu`. It installs a new mainline system rather
than preserving an old vendor installation. The shared design is recorded in
[ADR 0001](./adr/0001-independent-orangepi-firmware.md); support states are defined in the
[glossary](../GLOSSARY.md). No hardware installation or firmware validation has been performed by
preparing this guide.

## 1. Validate the firmware and live environment before touching disks

Start with the official [NixOS aarch64 minimal installation image](https://nixos.org/download/).
Select its latest-kernel boot entry when available. Record the resolved image filename, published
checksum, locally verified checksum, kernel version, firmware version and boot settings in the
[hardware validation record](./orangepi-hardware-validation.md). A moving download URL alone is not
an image version. Current NixOS installer source provides both the ordinary and latest-kernel
variants; that source evidence does not establish bootability on this board.
[Installer source](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/nixos/modules/installer/cd-dvd/installation-cd-minimal-combined.nix).

The installed-system target is EDK2 -> systemd-boot -> Linux EFI stub, using the firmware DT. In
EDK2 select `Config Table Mode = Device Tree`, `Device Tree Compatibility Mode = Mainline`, and
disable historical DTB overrides when using the bundled firmware DT. Record the actual settings.
Firmware is provisioned independently and remains unchanged during ordinary system updates. U-Boot
is an alternative live-environment boot candidate only if its EFI and board-DT handoff work on the
actual board; its native extlinux path is not the installed design.
[EDK2 settings](https://github.com/edk2-porting/edk2-rk3588#device-tree-configuration).

The live image may use GRUB even though the installed system uses systemd-boot. Before proceeding,
confirm that the board reaches a usable console, discovers the installation USB and NVMe, and has
working network access. Also check that the USB key device can be discovered. If any required path
fails, stop before formatting, retain serial output and investigate the concrete missing support.
Add a thin installer adaptation only if that evidence requires one; this repository does not
currently publish a board-specific installation image.

The official live account is `nixos`, not `rk`. Start at the physical/serial console. If SSH is
needed, enable access there using a public key or a locally entered temporary password, then SSH as
`nixos`. Never put a password, private key or unlock material in this repository or a transcript.

## 2. Confirm the target host and physical devices

From the live system, obtain the reviewed revision of this repository:

```console
git clone https://github.com/ryan4yin/nixos-config-sbc.git
cd nixos-config-sbc
git checkout <REVIEWED_COMMIT>
git rev-parse HEAD
```

Replace `<REVIEWED_COMMIT>` with the approved commit. Use the paths below; neither host directory
contains an underscore.

| Host       | Disk configuration                                        | Raw USB key label |
| ---------- | --------------------------------------------------------- | ----------------- |
| `rakushun` | [disko-fs.nix](../hosts/12kingdoms-rakushun/disko-fs.nix) | `OPI5P_DSC`       |
| `suzu`     | [disko-fs.nix](../hosts/12kingdoms-suzu/disko-fs.nix)     | `OPI5_DSC`        |

Inspect model, serial, size, transport, mountpoints and stable device links locally:

```console
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS
ls -l /dev/disk/by-id/
```

Set `disko.devices.disk.sda.device` in the selected host's configuration to the verified NVMe
`/dev/disk/by-id/...` path. The default `/dev/nvme0n1` is not proof of disk identity. Verify the
resolved path points to the intended NVMe and that neither the installer nor key USB is selected.
Preview the complete configuration before authorizing destruction. For `rakushun`:

```console
nix eval --raw .#nixosConfigurations.rakushun.config.disko.devices.disk.sda.device
nix run --inputs-from . disko -- --dry-run --mode destroy,format,mount --flake .#rakushun
```

Use `suzu` in both expressions for the second host. `--inputs-from .` resolves disko from this
flake's lock rather than a floating GitHub reference. Dry-run produces the formatting script; it
does not establish that a physical device is safe to erase. The operator must review the selected
target and generated actions before running them.

## 3. Prepare or verify the raw USB unlock key

The key consists of **32,768 bytes at offset 65,536** in the labelled USB partition. It is not a
file copied into a mounted FAT filesystem. Treat this USB partition as a dedicated raw key device;
ordinary filesystem use can overwrite the unlock material. The two host labels are distinct.

An existing correctly provisioned key can be reused. For a new key, the operator must separately
confirm the USB's physical identity before partitioning it, create the host-specific labelled
partition, and provision cryptographically random material only into the agreed raw region. Keep the
installation medium and key device distinct. Do not use a target chosen only because it currently
happens to be `/dev/sda`.

The following is an operator-run Bash example for a **new, disposable key USB**, after physical
target approval. Replace the stable ID first, inspect its resolved identity, and approve erasing
that USB before proceeding past `parted ... print`. For `suzu`, set `KEY_LABEL=OPI5_DSC` instead.
Run these steps in Bash rather than pasting assignments into Nushell. Do not enable shell tracing.

```bash
set -euo pipefail
KEY_DISK=/dev/disk/by-id/REPLACE_WITH_VERIFIED_USB_ID
KEY_LABEL=OPI5P_DSC
KEY_PART="${KEY_DISK:?}-part1"
test -b "${KEY_DISK:?}"
readlink -f "${KEY_DISK:?}"
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN,FSTYPE,LABEL,MOUNTPOINTS "${KEY_DISK:?}"
sudo parted "${KEY_DISK:?}" print

# Continue only after explicit approval to erase the inspected key USB.
sudo parted --script "${KEY_DISK:?}" mklabel gpt mkpart primary fat32 2MiB 512MiB
sudo udevadm settle --timeout=10
test -b "${KEY_PART:?}"
sudo mkfs.fat -F 32 -n "${KEY_LABEL:?}" "${KEY_PART:?}"
sudo udevadm settle --timeout=10
test "$(readlink -f "/dev/disk/by-label/${KEY_LABEL:?}")" = "$(readlink -f "${KEY_PART:?}")"
head -c 32768 /dev/urandom | sudo dd of="${KEY_PART:?}" bs=512 count=64 seek=128 iflag=fullblock conv=notrunc status=none
sync
```

The random material streams directly to the agreed raw region and is not printed or saved as a
regular file. Keep that partition dedicated to the raw key; do not mount it for ordinary file use.
The separately enrolled recovery passphrase remains essential if this USB is lost or damaged.

Inspect the label-to-device mapping and verify its partition identity before the NVMe format. Do not
display or dump the raw region to check it. The declared offset and size are the source of truth for
disko and initrd reads; changing them is a key-format migration.

## 4. Format and mount only after explicit target approval

The following command is destructive and runs only on the board after the operator has confirmed the
exact NVMe target and the key label. Do not use it for an existing installation update:

```console
sudo nix --extra-experimental-features 'nix-command flakes' run --inputs-from . disko -- --mode destroy,format,mount --flake .#rakushun
```

For `suzu`, replace the flake host with `suzu`. Do not use `--debug` when recording installation
output and do not bypass disko's destruction confirmation. The preserved layout is an unencrypted
630 MiB ESP mounted at `/boot`, LUKS2/Argon2id with Btrfs subvolumes underneath, and a tmpfs root.
Confirm the resulting `/mnt/boot`, `/mnt/nix` and `/mnt/persistent` mounts before installation. The
exact subvolumes and swap sizes remain defined in each host's disko module.

## 5. Enroll and test a recovery passphrase

Disko formats the LUKS volume with the raw USB key. It does **not** automatically enroll a recovery
passphrase. `keyFileTimeout = 10` only bounds waiting and permits an interactive fallback; a working
passphrase slot must be created separately.

For `rakushun`, identify and verify the encrypted partition before enrollment. Check the device
reference against the generated configuration and the verified NVMe partition:

```console
nix eval --raw .#nixosConfigurations.rakushun.config.boot.initrd.luks.devices.encrypted.device
ls -l /dev/disk/by-partlabel/disk-sda-luks
```

After confirming that this reference resolves to the newly formatted target, the operator runs:

```console
sudo cryptsetup luksAddKey --key-file /dev/disk/by-label/OPI5P_DSC --keyfile-offset 65536 --keyfile-size 32768 /dev/disk/by-partlabel/disk-sda-luks
sudo cryptsetup open --test-passphrase /dev/disk/by-partlabel/disk-sda-luks
```

Enter the new recovery passphrase only at the local interactive prompt. The first command
authenticates with the existing raw USB material and adds a passphrase slot; the second tests a
passphrase without opening another mapping. For `suzu`, use `OPI5_DSC` and its evaluated target. Do
not pass the new passphrase as an argument or save it to a file. If enrollment or verification
fails, stop before rebooting; the timeout setting alone is not recovery.

## 6. Install and initialize persistent identity

From the same reviewed checkout and mounted target, install the selected host:

```console
sudo nixos-install --root /mnt --flake .#rakushun --no-root-password
```

Use `.#suzu` for the second host. This installs systemd-boot and the system closure; it does not
provision board firmware. Verify the ESP contains the ARM64 EFI loader, current NixOS entry, kernel
and initrd. Entries must not include a `devicetree` override, and the selected firmware must supply
the Mainline DT. Preserve a verified live USB as the repair medium.

Before the first reboot, initialize the identity required by the configured preservation paths.
Review `/mnt/etc/machine-id`, `/mnt/etc/ssh` and their persistent counterparts locally. If the
installer generated them outside `/mnt/persistent`, move them to the configured persistent locations
only after confirming that those destinations do not contain identities to preserve. Do not print or
copy private SSH key contents into notes. Preserve ownership and permissions. Verify that the
configured user's home and login/authentication method are usable and persistent. The source of
truth is each host's preservation module; a tmpfs root cannot retain unpreserved installer-created
files across reboot.

## 7. Validate startup, recovery and daily operation

Complete the [hardware validation record](./orangepi-hardware-validation.md) for `rakushun` first.
Cold boot with the key inserted, then cold boot without it and unlock with the enrolled passphrase.
Check NVMe/filesystems, both Ethernet ports and their configured names, temperatures/fan behavior
and reboot. After those checks pass, repeat for `suzu` and verify Mitsuha startup and networking. No
ISO source declaration or successful closure build substitutes for these checks.

Manual generation recovery becomes testable after a subsequent system update creates another
installed generation. The board retains at most five generations, with a seven-second menu; this
bounds copied kernel/initrd files on the 630 MiB ESP. Check actual ESP free space before updates
because artifact sizes can grow. Record which entries are retained, select the previous mainline
generation and verify it boots. The retained firmware DT applies to all entries; a menu entry is not
a backup of firmware settings. Automatic boot failure assessment is outside this design.

For repair, boot the verified live USB, inspect the physical disk identities again, unlock the
existing LUKS volume interactively and mount its existing subvolumes and ESP. Use disko's
**mount-only** mode if appropriate for the existing layout; never use `--mode disko`, format or
destroy during recovery. Rebuild/reinstall the desired reviewed generation's boot files only after
reviewing the mounted target. Do not wipe the USB key region or enroll replacement keys as a side
effect of bootloader repair.

## 8. Move aarch64 back to nix-config after the stability gate

Both hosts must pass physical validation and run for at least 14 days, with two ordinary nixpkgs
updates including one actual kernel version upgrade. Boot, unlock, storage, networking and VM
blocking failures must be resolved before the move. Record revisions and observations rather than
forcing updates simply to reach a count. Migrate the small board module and host wiring while
reusing nix-config's shared configuration; keep RISC-V in this repository until its own migration is
verified. This repository remains the aarch64 validation workspace until that gate is met.
