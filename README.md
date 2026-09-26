<h2 align="center">:snowflake: Ryan4Yin's NixOS Config for SBCs :snowflake:</h2>

This repository is home to the nix code that builds my systems for Some Single Board Computers(SBCs)

See [./hosts](./hosts) for details of each host.

## Why a separate repository for SBCs?

SBC support (kernel / uboot / edk2 firmware) comes from external flakes — `nixos-rk3588` for aarch64
and `nixos-licheepi4a` for riscv64 — and each host takes its nixpkgs from those flakes. Keeping the
SBC hosts in their own flake lets them track a different nixpkgs line than
[nix-config](https://github.com/ryan4yin/nix-config) instead of coupling their slow,
hardware-dependent updates to the main repo's fast-moving nixpkgs.

> NOTE: all the SBC hosts in this repository are currently powered off / offline.

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
- [ryan4yin/nixos-rk3588](https://github.com/ryan4yin/nixos-rk3588/)
- [ryan4yin/nixos-licheepi4a](https://github.com/ryan4yin/nixos-licheepi4a/)
