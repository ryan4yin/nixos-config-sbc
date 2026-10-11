<h2 align="center">:snowflake: Ryan4Yin's NixOS Config for SBCs :snowflake:</h2>

This repository is home to the nix code that builds my systems for Some Single Board Computers(SBCs)

See [./hosts](./hosts) for details of each host.

## Supported configurations

| Configuration      | Hardware                  | Status                                                                                         |
| ------------------ | ------------------------- | ---------------------------------------------------------------------------------------------- |
| `suzu`, `rakushun` | Orange Pi 5 Plus          | Mainline nixpkgs kernel; software checks target these hosts. Hardware boot remains unverified. |
| `mitsuha`          | aarch64 MicroVM on `suzu` | Uses the updated nixpkgs and microvm.nix inputs.                                               |
| `nozomi`, `yukina` | Lichee Pi 4A              | Minimal evaluation compatibility fixes; kernel, system builds and boot remain unverified.      |
| Milk-V Mars        | JH7110                    | No host configuration is defined here.                                                         |

The Orange Pi hosts use the explicitly selected `nixos-unstable` input and the local
[`orangepi5plus` module](./nixos/boards/orangepi5plus.nix), with `linuxPackages_latest` rather than
the default kernel family. Host, MicroVM and tooling package sets all use unstable; tagged and
revision-pinned dependencies retain explicit references. Shared configuration follows the relevant
patterns already used in nix-config, including selective Ghostty/Kitty terminfo.

## Orange Pi boot and fresh installation

The installed boot path is EDK2 -> systemd-boot -> Linux EFI stub. The board explicitly sets
`installDeviceTree = false`, so the packaged `hardware.deviceTree.name` artifact is not substituted
for the firmware's Mainline DT. Firmware stays independent of routine system updates.

Use the [fresh installation and recovery procedure](./docs/orangepi-installation.md), including
verification that the official aarch64 latest-kernel live image actually boots on the board before
formatting. The procedure records firmware settings, preserves the existing storage/raw USB key
layout, and requires local enrollment and testing of a recovery passphrase. The configured 10-second
key timeout cannot create a missing passphrase slot.

Recovery covers previous mainline generations selected manually from systemd-boot and a verified
live USB. Old vendor installations have been cleared; preserving their loader/DT behavior is not a
requirement. Record real board results in the
[hardware validation record](./docs/orangepi-hardware-validation.md). Source-level differences
between systemd-boot and Limine are documented in the
[loader comparison](./docs/opi-efi-loader-comparison.md).

## Validation

```bash
# Supported aarch64 expression checks; failures must be an empty set.
just test-aarch64

# Evaluate complete Orange Pi system derivations without activation.
just eval-host suzu
just eval-host rakushun

# Build a system closure without deploying it.
just build-host rakushun

# Full-tree checks include the minimally repaired RISC-V configurations.
just test
```

CI runs strict full-tree expression checks and forces both OPi Colmena system derivations. RISC-V
has only received the compatibility fixes needed for the expression checks; its kernel, system
builds and boot remain unverified. aarch64 remains the primary validation target. Before deployment,
verify cold boot, USB-key/password unlock, NVMe, both Ethernet ports, thermal control, and the
MicroVM on the actual board.

## Path back to nix-config

This repository is the aarch64 validation workspace. After both Orange Pi hosts pass physical
acceptance, run for at least 14 days, and pass two ordinary nixpkgs updates including one kernel
version upgrade with no unresolved blocking issue, move their small board module and host wiring
back to nix-config. Keep RISC-V independent until its kernel/build/boot migration is validated. The
[validation record](./docs/orangepi-hardware-validation.md) tracks that gate; a successful closure
build alone does not satisfy it.

## Usage

```bash
# deploy microvms
just vm mitsuha

# deploy microvms & its host machine
just suzu-local # locally
just col suzu   # remotely

# deploy other hosts remotely
just col xxx
```

## References

- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config/)
- [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs/)
- [ryan4yin/nixos-licheepi4a](https://github.com/ryan4yin/nixos-licheepi4a/)
