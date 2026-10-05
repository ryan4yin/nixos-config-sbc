# RK3588 Mainline Migration Plan

> Tracking doc for moving the `12kingdoms` RK3588 hosts off the external `nixos-rk3588` flake
> (vendor kernel) onto the mainline kernel from nixpkgs, making this repo self-contained. Snapshot:
> 2026-10-05 (`main` = `5e14ab6`).

## 1. Goal

This repo's RK3588 hosts are `12kingdoms-suzu` (Orange Pi 5, RK3588S, 8 GB) and
`12kingdoms-rakushun` (Orange Pi 5 Plus, RK3588, 16 GB). Both run **headless as servers** (managed
with colmena; VMs via microvm.nix on `suzu`).

**Decision: use the mainline kernel only, and drop the `nixos-rk3588` input so this repo is
self-contained.**

Rationale: the mainline kernel from nixpkgs (`linuxPackages_latest`, currently 7.2.x) already covers
everything these servers need — Ethernet, PCIe/NVMe, SATA, USB, eMMC, cpufreq, thermal, GPU
(panthor) and HDMI — and it tracks nixpkgs security updates. Today the RK3588 hosts import
`nixos-rk3588.nixosModules.boards.orangepi5plus.core`, which pins an Armbian **vendor** kernel (6.1)
and a matching firmware set. We do not need the vendor kernel's extra features; see §3.

## 2. Decisions

| Item           | Decision                                                                                                                  | Notes                                                                                                     |
| -------------- | ------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| nixpkgs line   | bump to `nixos-unstable`                                                                                                  | brings kernel **7.2.9**; LTS fallbacks `6.18` / `6.12`                                                    |
| Kernel         | `boot.kernelPackages = pkgs.linuxPackages_latest`                                                                         | revert to an LTS kernel if 7.2 causes trouble                                                             |
| Device tree    | `hardware.deviceTree.name = "rockchip/rk3588s-orangepi-5.dtb"` (suzu), `"rockchip/rk3588-orangepi-5-plus.dtb"` (rakushun) | DTB names are unchanged in mainline, so the existing option keeps working once the kernel package changes |
| Boot params    | keep `console=ttyS2,1500000`, `earlycon`, `consoleblank=0`, `console=tty1`                                                | copied from the current board module                                                                      |
| Bootloader     | unchanged (existing SPI U-Boot / EDK2 UEFI flow)                                                                          | optional: nixpkgs `ubootOrangePi5` / `ubootOrangePi5Plus` for a self-contained SD image                   |
| Vendor support | not needed now                                                                                                            | reintroduce only if a workload (NPU / hardware encode) requires it                                        |

## 3. Mainline vs the vendor kernel

What the vendor kernel (Armbian `linux-rockchip` 6.1 `rkr5.1`) uniquely provides, and whether the
servers need it:

| Capability                | Mainline 7.2                                   | Vendor 6.1                | Needed here |
| ------------------------- | ---------------------------------------------- | ------------------------- | ----------- |
| NPU (RKNN / rkllama / ML) | `rocket`: convolutions only, RKNN-incompatible | `rknpu` 0.9.8             | no          |
| Hardware video encode     | no                                             | H.264/HEVC                | no          |
| Video decode              | VDPU381 H.264/HEVC                             | + AV1/VP9, 8K, multi-core | no          |
| Camera / ISP              | VICAP + CSI-2 receiver; ISP in progress        | full `rkisp`              | no          |
| Mali OpenCL               | no (panthor does GL/Vulkan)                    | vendor blob               | no          |
| HDMI input (RX)           | DWC driver, video only                         | `rk_hdmirx`               | no          |
| DMC / hardware crypto     | no                                             | yes                       | no          |

Mainline is also newer (7.2 vs 6.1), stays on nixpkgs security updates, and needs no vendor blobs.

## 4. Migration steps

- [ ] Bump this repo's nixpkgs to the current `nixos-unstable` (or add a dedicated kernel nixpkgs
      input so the rest of the repo stays pinned).
- [ ] Add a local board module (e.g. `nixos/boards/orangepi5.nix`) that inlines what `nixos-rk3588`
      provided: `kernelPackages`, `hardware.deviceTree` (name + overlays), `boot.kernelParams`,
      `hardware.firmware`, and the initrd / `supportedFilesystems` tweaks from the vendor module's
      `base.nix`.
- [ ] Point `suzu` / `rakushun` at the local module; drop `nixosModules.boards.orangepi5plus.core`.
- [ ] Drop the `specialArgs.rk3588` wiring in `outputs/aarch64-linux/src/*.nix`.
- [ ] Remove the `nixos-rk3588` input and the per-host `nixos-rk3588.inputs.nixpkgs` pin.
- [ ] `just test`, then hardware-verify (§5).

A minimal mainline starting point is `nixos-rk3588`'s `examples/upstream-opi/` (nixpkgs only, plus
`pkgs.ubootOrangePi5Plus`).

## 5. Verification

- `just test` stays green.
- On hardware (`suzu`, `rakushun`): boot, Ethernet, NVMe/SSD, USB, eMMC, cpufreq/thermal. HDMI is
  optional for these servers.
- Because this changes the kernel **and** the nixpkgs line, verify on hardware — not just eval.

## 6. Out of scope

- Keeping a vendor-kernel option (NPU / hardware encode). Add it later only if a workload needs it.
- Board support and the ready PRs (FriendlyELEC boards, systemd-boot, etc.) live in the
  `nixos-rk3588` repo, not here.

## 7. References

- kernel.org release list (stable `7.2.9`) and nixpkgs
  `pkgs/os-specific/linux/kernel/kernels-org.json`.
- Collabora: "Upstream support for Rockchip's RK3588" and follow-ups.
- `nixos-rk3588` `examples/upstream-opi/`.
