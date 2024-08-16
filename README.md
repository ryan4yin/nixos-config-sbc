<h2 align="center">:snowflake: Ryan4Yin's NixOS Config for SBCs :snowflake:</h2>

This repository is home to the nix code that builds my systems for Some Single Board Computers(SBCs)

See [./hosts](./hosts) for details of each host.

## Why a separate repository for SBCs?

It is troublesome to update nixpkgs on aarch64/riscv64 SBCs, which can easily cause various problems
such as kernel compilation failure and boot failure caused by uboot/edk2 incompatibility. So it
feels like a good idea to create separate flakes for SBCs and have them updated separately.

## References

- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config/)
- [ryan4yin/nixos-rk3588](https://github.com/ryan4yin/nixos-rk3588/)
- [ryan4yin/nixos-licheepi4a](https://github.com/ryan4yin/nixos-licheepi4a/)
