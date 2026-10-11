# Mainline SBC feasibility: RK3588, JH7110 and TH1520

Research snapshot: **2026-10-10**. Scope: Orange Pi 5 Plus, Milk-V Mars (the SBC, not Mars CM), and
Sipeed Lichee Pi 4A. This report evaluates reducing recurring vendor-kernel maintenance by keeping a
tested boot-firmware image separate from an upstream Linux kernel, its DTBs, and userspace. It does
not claim hardware validation. During the initial source audit, no downloaded source or build
scripts were executed, no system builds, activation or flashing occurred, and Python was used only
to retrieve research material.

**Repository audit baseline:** commit `80b739f2058321cc755157ed77fb1f1568cc6204`, before the input
and OPi migration. Baseline code citations below are pinned to that revision. For the implemented
configuration and validation scope, see the
[current README](../README.md#orange-pi-boot-and-fresh-installation). The OPi implementation uses
systemd-boot with `installDeviceTree = false` and requires an upstream-derived firmware DT; the
packaged kernel DTB is not substituted at boot. A newer kernel may use an older compatible upstream
DT under the [stable DT binding ABI](https://docs.kernel.org/devicetree/bindings/ABI.html).

## Recommendation

**Orange Pi 5 Plus is the strongest first migration candidate. Milk-V Mars has a credible upstream
headless path, with a board-DTB selection caveat. Lichee Pi 4A has both a conservative
retained-firmware path and a concrete new coreboot/OpenSBI/EDK2 candidate published in RevyOS's
20260926 mirror; the latter could provide the preferred standardized boot experience once its
provenance and hardware behavior are verified.** All three boards have their own DT in the Linux
v7.2 release tree. That establishes merged board descriptions, not equivalent peripheral coverage or
a successful NixOS boot on the actual hardware. [OPi DT][opi-dt] [Mars DT][mars-dt] [LP4A
DT][lpi-dt]

The practical target is:

- A separately pinned, recoverable boot-firmware artifact, updated deliberately rather than rebuilt
  on every userspace upgrade.
- An upstream kernel and packaged board DTB from the selected nixpkgs revision, with an explicitly
  verified handoff of a compatible upstream DT from firmware or the loader.
- A small local board module covering console, boot partition/loader, initrd storage and network
  drivers, firmware files, and any necessary boot handoff.
- Removal of external kernel-port flakes only after their non-kernel responsibilities have been
  replaced and the target hardware passes the acceptance checks below.

This can make `nixos-rk3588` and `nixos-licheepi4a` unnecessary **as kernel-port dependencies**. It
does not make board configuration, provisioning, SBI/TF-A, DDR initialization, or peripheral
firmware unnecessary. Prefer one deliberately selected host nixpkgs input and small local board
modules. A separate firmware flake/input is optional: provisioning packages can remain lazy package
outputs outside `system.build.toplevel`, with a fixed artifact hash, version ledger and recovery
image. Routine system rebuilds then need not force a firmware build, and flashing remains an
explicit provisioning step. The sections below audit the existing dependency points and the current
nixpkgs alternatives.

## Versions and evidence boundaries

| Project            | Live result                                                                                                                                | How it is used here                                                                                                                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Linux              | kernel.org reports stable **7.2.9**, released 2026-10-03; mainline **7.3-rc6**, released 2026-10-04; longterm **6.18.55** and **6.12.112** | Board and peripheral claims below are anchored to the **v7.2 release tree**, not inferred from a release candidate or linux-next. Older LTS coverage must be checked separately. [Release index][kernel-releases]                              |
| U-Boot             | Official repository tag API lists **v2026.10** ahead of v2026.10-rc5                                                                       | Read the board documentation and defconfigs at **v2026.10**. The fetched `master` Makefile reported 2026.07, so moving-branch content was not treated as authoritative evidence of the newest release. [Tags][uboot-tags] [Tag ref][uboot-tag] |
| TianoCore EDK2     | Official latest-release API reports **edk2-stable202608**, published 2026-08-21                                                            | This is a core EDK2 release, not a release of firmware images for these boards. [Release][edk2-release]                                                                                                                                        |
| RK3588 EDK2 port   | The port project's latest-release API reports **v1.1**, published 2025-04-09, including an Orange Pi 5 Plus image                          | A separate community platform port; its version must not be confused with the current TianoCore core version. Its release notes say embedded upstream DTs were updated to **v6.15-rc1-dts**. [Release][rk-edk-release]                         |
| Trusted Firmware-A | **v2.14.0** contains the RK3588 platform and BL31 source list                                                                              | Evidence of an available released open-source BL31 implementation, not an assertion that this is TF-A's newest release or that every feature matches Rockchip's binary. [RK3588 platform][tfa-rk3588]                                          |

The source snapshots are not a tested combination. A released source file proves inclusion in that
release; `status = "okay"` proves board enablement in DT; neither proves operational reliability,
throughput, suspend behavior, or complete distro packaging. Mailing-list patches are not counted as
merged unless the released tree supplies corresponding evidence.

## Orange Pi 5 Plus / RK3588

### Linux: merged boot essentials and broader board enablement

The v7.2 board has `compatible = "xunlong,orangepi-5-plus", "rockchip,rk3588"` and includes the
Orange Pi 5 family DT. The family DT enables SD, eMMC, SPI NOR, serial2 at 1500000 baud, PCIe 3 x4,
USB host controllers, regulators, thermal monitoring and fan cooling. The Plus DT enables the
separate PCIe links annotated for the left and right Ethernet ports and the additional socket. These
are strong source-level grounds to evaluate a storage-and-Ethernet server without the vendor kernel.
[Board DT][opi-dt] [Family DT][opi-common]

Peripheral support has advanced beyond early RK3588 bring-up: the v7.2 board describes both HDMI
outputs and their sound paths, HDMI receiver, analog audio and Type-C orientation/role connections;
the family DT enables GPU and all three `rknn` cores. Consequently, blanket statements such as
“mainline RK3588 has no HDMI/NPU support” are out of date for this snapshot. These nodes do **not**
establish full vendor-SDK compatibility, working inference runtimes, every codec format, camera
pipelines, or every display mode. Those remain separate workload acceptance items. [Board
DT][opi-dt] [Family DT][opi-common]

### Boot firmware and unavoidable binaries

U-Boot v2026.10 has a dedicated `orangepi-5-plus-rk3588_defconfig`, the correct default board DTB,
SPI-image support, MMC, PCIe/NVMe and USB support. The official Rockchip guide documents SD/eMMC/SPI
provisioning and the `ROCKCHIP_TPL` DDR artifact. A tested upstream U-Boot image is therefore a
reasonable long-lived boot layer. [Defconfig][opi-uboot] [Rockchip guide][rockchip-guide]

The guide's RK3588 example still supplies **both** DDR initialization and BL31 from Rockchip
`rkbin`. That example should not be generalized into “BL31 is inevitably proprietary”: TF-A
**v2.14.0** includes a BSD-licensed RK3588 platform with BL31 sources for CPU, PMU, clocks, reset
and secure setup. An upstream TF-A BL31 can be selected, subject to validation of the chosen
board/firmware combination. The **rkbin DDR/TPL binary remains the practical external boot artifact
in the documented U-Boot route**. [Guide][rockchip-guide] [Released TF-A platform][tfa-rk3588]

GPU firmware is a separate, optional runtime dependency for a headless server: the upstream Panthor
driver explicitly requests `arm/mali/arch<major>.<minor>/mali_csffw.bin`. Selecting the upstream
driver does not eliminate that binary. Wireless firmware depends on the installed module and should
not be inferred from the SoC name. [Panthor firmware loader][panthor-fw]

### EDK2: viable optional port, not required for mainline Linux

The RK3588 port lists Orange Pi 5 Plus in its Platinum tier and supports a **Mainline Device Tree**
mode for generic upstream Linux. Its documentation explicitly recommends DT for rich Linux support
and says ACPI development/testing is focused on Windows. It also supports overriding the firmware's
bundled DTB with an OS-provided DTB. This is useful because v1.1's embedded DT snapshot is
considerably older than Linux v7.2. [Port documentation][rk-edk-readme] [v1.1 notes][rk-edk-release]

This is `edk2-porting/edk2-rk3588`, not proof that the board is supported by an unmodified current
TianoCore platform build. The port also contains `rkbin` components and is not a route around DDR
initialization binaries. Its firmware-level USB-C/FUSB302 limitations must be distinguished from
Linux's own driver support. For reducing kernel update failures, use the already-tested loader if
possible; introducing EDK2 is an optional boot-interface change with its own validation cost. [Port
documentation and licenses][rk-edk-readme]

**Cost judgement:** high confidence in trying upstream Linux for headless use; lower confidence in
replacing a vendor multimedia/AI stack without workload-specific testing. Fixed DDR firmware is a
much smaller recurring maintenance surface than a vendor kernel tree.

## Milk-V Mars / JH7110

### Mars has its own Linux DT

Linux v7.2 contains `jh7110-milkv-mars.dts`, with model `Milk-V Mars` and
`compatible = "milkv,mars", "starfive,jh7110"`. It is not merely a VisionFive 2 name alias. It adds
Mars-specific Ethernet clocks/PHY delays, eMMC wiring, SD-card detect, PCIe enables and USB host pin
control on top of `jh7110-common.dtsi`. The common DT enables the serial console, MMC interfaces,
QSPI flash and the PMIC. These are credible ingredients for a headless server, but still require
testing the actual RAM size and boot medium. [Mars DT][mars-dt] [Common DT][jh-common]

Do not transfer all VisionFive 2 peripheral claims to Mars. The inspected Mars/common DTs do not
enable a complete HDMI display graph or prove accelerated graphics. The presence of a SoC driver, or
a common SoC feature list in the U-Boot documentation, is insufficient evidence for a working
board-level display/camera/audio stack. [Mars DT][mars-dt] [Common DT][jh-common] [U-Boot common
documentation][jh-uboot]

### U-Boot is shared, Linux DT selection still needs attention

The released U-Boot Mars document explicitly says Mars uses **the same U-Boot binaries as VisionFive
2**, with board detection and DT patching in SPL. Thus the absence of a Mars-named defconfig does
not mean there is no upstream Mars boot support. The documented build target is
`starfive_visionfive2_defconfig`, with OpenSBI generic `fw_dynamic.bin`; the current shared
documentation requires OpenSBI **v1.5+** and illustrates v1.7. [Mars boot document][mars-uboot]
[Common build instructions][jh-uboot]

There is an integration trap: the same Mars document says `fdtfile` may default to VisionFive 2
v1.2a/v1.3b DTBs and explains how to override it. **Explicitly arrange delivery of
`starfive/jh7110-milkv-mars.dtb` to Linux and verify the effective DT at boot.** Firmware board
detection alone does not establish that the independently loaded Linux DTB is correct. [Mars boot
document][mars-uboot] [Linux Mars DT][mars-dt]

For fresh provisioning, follow the current documented **QSPI firmware plus separately loaded OS**
route. U-Boot's shared document marks direct BootROM SD/eMMC modes deprecated from v2025.10 and
describes their layout/compatibility problems. That concerns the early firmware loading path, not a
prohibition on Linux using SD/eMMC or U-Boot proper loading an OS from them. The example logs in
this shared document identify **Pine64 Star64**, so they are not evidence of a tested Mars image.
[Boot modes and example logs][jh-uboot]

### Firmware and EDK2

The documented boot-image inputs are upstream U-Boot SPL, OpenSBI and U-Boot proper. The DDR driver
is in the released GPL-licensed U-Boot source; this route does not document an additional external
DDR blob requirement. That is a narrower claim than proving every bit in the chip is open: the same
documentation says StarFive has not published its on-chip BootROM. [DDR driver][jh-ddr] [Boot
documentation][jh-uboot]

No maintained Mars-specific TianoCore platform was established by this research. The inspected
current `edk2-platforms` Platform/Silicon listings contain no StarFive platform directory. RISC-V
support in EDK2 core, and vendor or mailing-list JH7110 work, must not be represented as a released
Mars platform. Use OpenSBI plus upstream U-Boot as the evidence-backed route; an EDK2 investigation
adds maintenance without being necessary to use the upstream Linux DT. [Platform
listing][edk-platforms] [Silicon listing][edk-silicon] [RISC-V directory][edk-riscv]

**Cost judgement:** credible upstream headless route and comparatively small external firmware
surface. Remaining costs include RISC-V userspace/build infrastructure, correct board DT selection,
and RAM/boot-medium testing; those are not solved by kernel upstreaming.

## Lichee Pi 4A / TH1520

### Linux support is substantially more than a serial-only bring-up

Linux v7.2 contains the LP4A board DT, its module DT and the TH1520 SoC DT. The module enables eMMC,
SD, DMA and **both** Ethernet MACs; the board enables the serial console, thermal/PWM fan, SDIO
wiring and HDMI/DPU graph. The SoC DT also has GPU, AON mailbox/power-domain and noncoherent DMA
descriptions. It is therefore reasonable to test upstream Linux for an eMMC/SD plus Ethernet server,
and inaccurate to say the released kernel only has UART support. [Board][lpi-dt]
[Module][lpi-module] [SoC][th-soc]

Conversely, this is not proof of all advertised board peripherals. The inspected v7.2 SoC DT does
not provide a USB controller path; the board's SDIO power sequencing does not prove its Wi-Fi
driver/firmware works; HDMI enablement does not prove GPU acceleration or a vendor multimedia stack.
Do not require USB storage, cameras, NPU, DSP audio, wireless or suspend in the initial migration
acceptance target. GPU power management references AON, so even a display-oriented migration needs a
separate firmware handoff audit. [Board][lpi-dt] [SoC][th-soc]

The CPU DT describes `xtheadvector`, not the standard `v` extension. Avoid treating TH1520's
advertised vector capability as a guarantee that generic RVV 1.0 binaries will run. A conservative
userspace baseline remains appropriate. [CPU ISA description][th-soc]

### Upstream U-Boot is merged, but persistent autonomous boot is not established

The released v2026.10 documentation and `th1520_lpi4a_defconfig` establish upstream board support.
Its documented image includes **SPL + DDR firmware + OpenSBI + U-Boot proper**, using generic
OpenSBI **v1.2 or newer**. The documentation explicitly demonstrates **fastboot loading to RAM**,
UART and MMC. The original 2025 DDR/SPL mailing-list work must no longer be called wholly pending:
the released configuration enables `CONFIG_SPL_THEAD_TH1520_DDR`. [Released guide][lpi-uboot-guide]
[Released defconfig][lpi-uboot] [Original DDR patch][th-ddr-mail]

However, v2026.10 still sets `CONFIG_SPL_RAM_DEVICE=y`, disables `CONFIG_EFI_LOADER`, uses an empty
`CONFIG_BOOTCOMMAND`, and disables saving the environment in the board defconfig. The cited evidence
does **not** establish a turnkey persistent eMMC/SPI boot path, automatic NixOS generation
selection, or an EDK2-like EFI environment. Linux MMC support and U-Boot proper MMC support do not
by themselves solve BootROM-to-SPL loading. Treat a full boot-firmware replacement as additional
engineering. [Defconfig][lpi-uboot] [Guide][lpi-uboot-guide]

The cheapest transition is likely **retain a known-working, fixed firmware/loader and test a
matching upstream kernel + DTB**, then separately improve the boot firmware. This is a
recommendation, not a verified compatibility claim: the old loader must pass the expected memory
map, reserved areas, SBI services and firmware state to the new kernel.

### DDR and AON are different firmware obligations

The U-Boot guide requires a generated DDR firmware image from `th1520-firmware`. That project's own
description says the data is extracted from vendor initialization code and contains **both register
settings and ARCv2 PHY MCU programs for 1D/2D training**. Being generated by Lua does not make the
embedded MCU program source available. Its README lists the dual-rank LPDDR4X configuration for **8
GiB and 16 GiB** LP4A, including preview boards; this does not establish coverage of every 4 GiB or
other memory variant. [U-Boot guide][lpi-uboot-guide] [Firmware collection][th-fw]

The same firmware project describes AON as implementing PMIC/power-domain/watchdog and
suspend/resume services. It labels U-Boot AON facilities work in progress, says released vendor AON
binaries lack a clear redistribution/modification license, and links published AON source with no
license information. Source visibility is therefore insufficient to promise a reproducible,
redistributable replacement. AON is not equivalent to OpenSBI or DDR training and must remain a
separately audited boot/runtime input where required. [Firmware collection][th-fw] [Kernel AON
references][th-soc]

Existing board images may also load C906 audio firmware. Whether it can be omitted depends on the
selected audio/runtime requirements and boot scripts; it is not established as necessary for a
minimal Ethernet server by the upstream U-Boot build recipe. Removing that file, or the AON image,
should follow an audit of their actual loading/use rather than a blanket “upstream kernel needs no
firmware” assumption. [Upstream image inputs][lpi-uboot-guide] [AON functions][th-fw]

No maintained LP4A/TH1520 TianoCore board platform was established in the inspected upstream
platform listings. EDK2 core's RISC-V support is insufficient to initialize this board or supply its
DDR/AON services. Avoid making EDK2 a prerequisite for this migration. [Platform
listing][edk-platforms] [Silicon listing][edk-silicon]

### RevyOS: distinguish the maintained distro stack from upstream Linux

RevyOS is the relevant practical reference for LP4A. Its official project index separately lists the
old 5.10.113 vendor kernel, `th1520-linux-kernel`, the newer multi-platform `revyos/linux`, boot
firmware, vendor U-Boot and image-generation scripts. These repositories have different roles and
release histories. The installation page calls **20251226 / kernel 6.6** the latest image and
describes 20240720 / 5.10 as the mature multimedia stack, while warning about video stutter and USB
power loss on the described 6.6 images. This is the page's documented guidance, **not the newest
artifact inventory**. The inspected official **20260504** directory contains compressed boot/root
filesystem images, a full SD-card image and U-Boot/SPL variants, establishing a newer full OS-image
set than 20251226. Its `README.md` returns 404 and the directory listing supplies no kernel package
version, so the **kernel shipped in that full image remains unverified**; no image binary was
downloaded. The later **20260926** directory described below is a boot-firmware release, not a newer
full OS image.
[20260504 image directory](https://mirror.iscas.ac.cn/revyos/extra/images/lpi4a/20260504/)
[Official project index](https://docs.revyos.dev/en/projects/)
[Installation guidance](https://docs.revyos.dev/en/docs/Installation/licheepi4a/)

The live `th1520-linux-kernel` default `th1520-lts` branch resolves to
`a092d55649279e1c9bcda2769b8f6b4370fa2c94`, whose Makefile reports **6.6.141**. Meanwhile
`revyos/linux` has separate branches including `revyos/7.2.y`, `revyos/7.3.y` and `debian/7.2.6`. A
maintained 6.6 branch is not evidence that all current RevyOS work is on 6.6; a 7.x branch is not
evidence that a particular LP4A disk image ships it or that its patches are all merged upstream.
[6.6 branch metadata](https://api.github.com/repos/revyos/th1520-linux-kernel/branches/th1520-lts)
[Pinned version](https://github.com/revyos/th1520-linux-kernel/blob/a092d55649279e1c9bcda2769b8f6b4370fa2c94/Makefile)
[Newer branch listing](https://api.github.com/repos/revyos/linux/branches?per_page=20)

The inspected image-build package list makes a useful architectural distinction: normal
`KERNEL_lpi4a` selects `linux-image-6.6-th1520`, while the separate `KERNEL_th1520main` selects
Debian `linux-image-riscv64`. **Both still install `th1520-mainline-opensbi`, `th1520-boot-firmware`
and wireless firmware.** Thus RevyOS itself contains an example of changing the kernel source while
keeping explicit firmware responsibilities. Its mainline target name does not prove complete LP4A
peripheral parity or NixOS compatibility.
[Package selection](https://github.com/revyos/mkimg-th1520/blob/main/scripts/packages_list.sh)

The vendor branch preserves substantial board integration absent from the inspected upstream board
DT: USB hub supplies and controller enablement, wireless platform data, C906 mailbox/RPMsg audio,
camera/ISP paths, NPU enablement and extensive reserved audio/DSP/video memory. This directly
explains why replacing a RevyOS-derived kernel can change peripheral behavior even when both trees
have an LP4A DTS. It does not establish that every downstream feature works or that every patch
remains absent from every newer upstream branch.
[Downstream board DT](https://github.com/revyos/th1520-linux-kernel/blob/th1520-lts/arch/riscv/boot/dts/thead/th1520-lichee-pi-4a.dts)
[Upstream v7.2 board DT][lpi-dt]

More importantly, the currently linked `thead-u-boot` repository redirects to
**`th1520-vendor-uboot`**. Its `light-c910.h` boot environment loads AON, C906 audio, `str.bin` and
OpenSBI, then performs `fixup_memory_region`, `bootslave` and extlinux boot. The RevyOS SD image
layout reserves its first 2031 KB as **unused**, and the SD image creation script does not install
an SPL there; the installation guide says to leave the boot switches in the **eMMC position**. This
evidence supports an OS-on-SD workflow using an already provisioned loader, not a claim that the SD
image supplies an independent replacement firmware chain.
[Vendor boot environment](https://github.com/revyos/th1520-vendor-uboot/blob/th1520/include/configs/light-c910.h)
[SD layout](https://github.com/revyos/mkimg-th1520/blob/main/sdcard_template.cfg)
[SD image creation](https://github.com/revyos/mkimg-th1520/blob/main/scripts/create_sdcard.sh)
[Installation guide](https://docs.revyos.dev/en/docs/Installation/licheepi4a/)

The boot-firmware package's inspected changelog begins at **2025.05.10+sdk2.0.2**: it removes vendor
OpenSBI, adds Debian OpenSBI and records mainline OpenSBI revisions. Its packaging still distributes
AON, C906 audio and `str.bin` separately from the OpenSBI variants; its copyright file supplies only
a description rather than licensing terms. This package version describes that repository snapshot,
not necessarily the newest bootloader release. Preserve the distinction between redistributable
OpenSBI source and other firmware payloads.
[Changelog](https://github.com/revyos/th1520-boot-firmware/blob/master/debian/changelog)
[Packaging](https://github.com/revyos/th1520-boot-firmware/blob/master/debian/rules)
[Payload inventory](https://api.github.com/repos/revyos/th1520-boot-firmware/git/trees/master?recursive=1)
[Copyright text](https://github.com/revyos/th1520-boot-firmware/blob/master/debian/copyright)

The upstream module DT has an **8 GiB default memory description**. A 4/8/16 GiB board and retained
firmware must supply the correct effective RAM range and preserve required firmware reservations.
Passing an unmodified freshly built DTB without verifying the loader's fixups risks losing the
behavior supplied by RevyOS's boot chain. [Upstream memory node][lpi-module]
[Vendor fixup invocation](https://github.com/revyos/th1520-vendor-uboot/blob/th1520/include/configs/light-c910.h)

### RevyOS 20260926 firmware: a newer independent EDK2 boot path

The official mirror's **20260926** README changes the boot-firmware assessment: it explicitly
documents **coreboot + OpenSBI + EDK2**, with native coreboot DDR initialization and **no U-Boot SPL
or runtime**. It provides a 1 MiB RAM-recovery image and a 2 MiB normal `lpi4a-emmc-boot0.bin`
image. This is a persistent eMMC firmware route independent of the restricted upstream U-Boot
defconfig described above. It is a boot-firmware release, not a new Linux/root-filesystem release.
[Official firmware README](https://mirror.iscas.ac.cn/revyos/extra/images/lpi4a/20260926/README.md)
[Artifact directory](https://mirror.iscas.ac.cn/revyos/extra/images/lpi4a/20260926/)

The README states support for dual-rank **8/16 GiB** DDR profiles, capacity determined by physical
probes rather than DT memory size, AON startup and CPU-rail voltage verification before 1848 MHz. It
requires cooling. Its recovery procedure writes `emmcboot0`, reads the written image back for
verification, preserves the final 8 KiB of boot0 for MAC records and preserves eMMC boot selection.
These are release-author claims, not tests performed here.
[Official README](https://mirror.iscas.ac.cn/revyos/extra/images/lpi4a/20260926/README.md)

This evidence means LP4A **does have a concrete newly published EDK2-based boot candidate**. It does
not establish that the board support is merged into unmodified TianoCore, coreboot or OpenSBI
releases: the README does not identify their source revisions, embedded DDR PHY/AON payload
provenance, licenses, or a Linux/NixOS peripheral validation matrix. In particular, “native coreboot
DDR initialization” does not by itself prove that no PHY training microcode remains. Do not carry
the old U-Boot image's firmware-file loading rules over to this different chain without inspecting
its source and effective DT handoff.
[Official README](https://mirror.iscas.ac.cn/revyos/extra/images/lpi4a/20260926/README.md)

The finite source-attribution check found a RevyOS `edk2-platforms` fork, but its advertised
branches were only `master`, `sg2042/fdt` and `sg2044/fdt`; these do not identify the LP4A release
sources. The inspected upstream coreboot SoC directory has no T-Head/TH1520 vendor directory, and
the direct `revyos/coreboot` repository lookup returned 404. These observations support **unresolved
source attribution**, not a claim that the release cannot work or that its sources do not exist
elsewhere. A coreboot payload can also use generic EDK2 code without a separate TianoCore LP4A
platform directory.
[RevyOS EDK2 branches](https://api.github.com/repos/revyos/edk2-platforms/branches?per_page=30)
[Coreboot SoC inventory](https://api.github.com/repos/coreboot/coreboot/contents/src/soc)
[RevyOS coreboot lookup](https://api.github.com/repos/revyos/coreboot)

For the maintenance objective, this release is worth evaluating as a **separately pinned
provisioning artifact** and could become the preferred LP4A boot UX. First obtain the build
manifest/source revisions and identify DDR PHY/AON payloads; verify the 8/16 GiB board match, actual
RAM/reserved regions, NixOS EFI bootloader compatibility, generation selection, persistent boot
settings and the documented recovery procedure. Until those are verified, retain the known-working
chain as the production baseline. The upstream U-Boot limitations remain specific to that
implementation, not a statement that all LP4A persistent boot or EDK2 options are unavailable.
Firmware does not supply a missing Linux USB controller driver/DT path: the v7.2 kernel peripheral
limits above still apply even if firmware's own USB recovery works.

**Cost judgement:** meaningful opportunity to remove vendor-kernel build churn for a restricted
headless workload; the highest firmware/provisioning uncertainty of these three boards. Keep the
working boot chain while testing the kernel independently. Use RevyOS sources as the reference for
required handoff behavior and optional peripherals, rather than deleting its integration solely
because the mainline DT exists.

## Merged, pending and unverified: decision record

| Item                                                                 | Classification at this snapshot                                                                                | Consequence                                                                                                                                                                                                                          |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Three board Linux DTs                                                | Merged and present in Linux **v7.2**                                                                           | No out-of-tree board DTS is inherently required for the basic board identity. [OPi][opi-dt] [Mars][mars-dt] [LP4A][lpi-dt]                                                                                                           |
| OPi 5 Plus U-Boot target                                             | Merged in **v2026.10**                                                                                         | Upstream provisioning artifact is available in source. [Defconfig][opi-uboot]                                                                                                                                                        |
| Mars shared VF2 U-Boot support                                       | Documented in **v2026.10**                                                                                     | Shared firmware is intentional; Linux DT selection still needs correction/verification. [Guide][mars-uboot]                                                                                                                          |
| TH1520 initial DDR/SPL patches                                       | Released configuration contains support                                                                        | Do not label a 2025 patch series “still pending” from its mailing-list subject alone. [Mail][th-ddr-mail] [Defconfig][lpi-uboot]                                                                                                     |
| TH1520 AON integration in the firmware collection                    | Project documentation explicitly says work in progress                                                         | A full replacement boot chain cannot be assumed complete. [README][th-fw]                                                                                                                                                            |
| RevyOS 20260926 LP4A firmware                                        | Published coreboot/OpenSBI/EDK2 eMMC + RAM-recovery artifacts; source attribution unresolved                   | A real independent boot candidate; does not establish merged TH1520 support in upstream coreboot/TianoCore or complete Linux peripherals. [Official README](https://mirror.iscas.ac.cn/revyos/extra/images/lpi4a/20260926/README.md) |
| Pure current TianoCore board firmware for these three targets        | Not established; RK3588 has a separately maintained port and RevyOS publishes a coreboot/EDK2 LP4A combination | Evaluate concrete port/release artifacts separately from core EDK2 version numbers. [TianoCore platforms][edk-platforms] [RK3588 port][rk-edk-readme]                                                                                |
| Every peripheral, NixOS boot, persistent LP4A upstream firmware boot | Not verified here                                                                                              | Requires board/workload validation; absent evidence is not automatically a claim of permanent upstream rejection.                                                                                                                    |

The research does not claim an exhaustive inventory of all mailing-list patches currently under
review. Items without released implementation evidence are excluded from the baseline rather than
promised for a future kernel.

## Hardware acceptance before activating the migration

1. Boot the selected upstream kernel **with a compatible upstream board DT** from the retained
   firmware using removable/recoverable media; capture serial output and verify the effective board
   identity, RAM capacity, reserved memory and SBI/PSCI handoff.
2. Confirm root storage and initrd drivers, Ethernet address/link/DHCP, sustained storage/network
   I/O, thermal/fan behavior and clean reboot. Test the actual ports used by the host, including
   both OPi/LP4A NICs where needed.
3. Confirm the installed system can select a new generation and recover the previous kernel,
   including its required firmware DT mode and override settings, without rewriting boot firmware.
   LP4A's upstream defconfig does not establish this workflow automatically.
4. Inventory what the external port module supplies besides its kernel: image layouts, firmware
   loading, boot scripts, firmware packages and initrd configuration. Move only the required
   board-specific pieces into local modules or a separately pinned provisioning package.
5. Only after those checks pass, activate the configuration that removes the external kernel-port
   dependency. Keep firmware revisions/hashes and a recovery image independent of routine nixpkgs
   updates. Optional peripherals receive their own acceptance tests if the workload needs them.

These are proposed future hardware checks; none was run during research. Mainline removes a major
source of vendor-kernel/compiler incompatibility, but it cannot guarantee regression-free kernel
updates or the same binary-cache coverage across aarch64 and riscv64.

## Repository audit and migration implications

### Updating the root nixpkgs input alone does not update these physical hosts

The root input is `nixos-24.11`, but physical hosts explicitly override it with the board-port
input's package set. Both `suzu` and `rakushun` use `nixos-rk3588.inputs.nixpkgs` for NixOS
evaluation, kernel arguments and Colmena `nodeNixpkgs`. The locked RK3588 nixpkgs revision is
`4c2fcb090b1f3e5b47eaa7bd33913b574a11e0a0` (2024-era pin). Both `nozomi` and `yukina` use
`nixos-licheepi4a.inputs.nixpkgs`, locked to `nixos-23.05-small` revision
`240472b7e47a641e9e7675f58b64d3626ca7824d` (2023-era pin). A root-input update therefore cannot
deliver the current upstream kernel or userspace to these hosts.
[Root inputs](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/flake.nix#L32)
[Locked board dependencies](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/flake.lock#L875)
[Locked nixpkgs revisions](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/flake.lock#L1128)
[Suzu wiring](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/outputs/aarch64-linux/src/12kingdoms-suzu.nix#L33)
[Rakushun wiring](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/outputs/aarch64-linux/src/12kingdoms-rakushun.nix#L35)
[Nozomi wiring](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/outputs/riscv64-linux/src/rolling-girls-nozomi.nix#L35)
[Yukina wiring](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/outputs/riscv64-linux/src/rolling-girls-yukina.nix#L35)

The two configured physical RISC-V hosts are explicitly **Lichee Pi 4A**. There is no active Mars
host configuration in the inspected outputs, and the JH7110 input is commented out. Mars is a
hardware-option comparison, not a proposed reclassification of either existing LP4A host.
[Nozomi board import](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/hosts/rolling-girls-nozomi/default.nix#L8)
[Yukina board import](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/hosts/rolling-girls-yukina/default.nix#L8)
[RISC-V output wiring](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/outputs/default.nix#L34)
[Commented JH7110 input](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/flake.nix#L90)

### A complete port removal covers both evaluation and boot-image duties

For RK3588, replacing the vendor kernel requires replacing the imported `orangepi5plus.core` board
module **and** the port-specific `rk3588`/`pkgsKernel` arguments and package sets in both NixOS and
Colmena wiring. Keep the local storage, network, disko and host configuration. For LP4A, both host
modules import the board module and the SD-image module, so deleting only `boot.kernelPackages` or
switching one nixpkgs argument leaves substantial port dependencies. This is a future change
inventory; no such configuration change was made here.
[Suzu imports](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/hosts/12kingdoms-suzu/default.nix#L18)
[Rakushun imports](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/hosts/12kingdoms-rakushun/default.nix#L17)
[RK package wiring](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/outputs/aarch64-linux/src/12kingdoms-suzu.nix#L33)
[LP4A imports](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/hosts/rolling-girls-nozomi/default.nix#L15)
[LP4A package wiring](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/outputs/riscv64-linux/src/rolling-girls-nozomi.nix#L35)

At the locked LP4A port revision, its SD-image module sets a root UUID and kernel command line,
enables extlinux, forcibly defines filesystems, builds the boot partition and copies **OpenSBI, AON
and C906 audio** into it. Its flake builds the old RevyOS `thead-kernel` with a dedicated
compiler/overlay. Those image and handoff duties must either remain in a small local compatibility
module or be deliberately replaced by a verified new firmware/EFI workflow. The 20260926
coreboot/EDK2 release is a genuine replacement candidate; its source and DT handoff still require
the provenance checks described above.
[Pinned SD-image module](https://github.com/ryan4yin/nixos-licheepi4a/blob/0fb4b65137de445de543ed8532d4aac6ecc27271/modules/sd-image/sd-image-lp4a.nix)
[Pinned port flake](https://github.com/ryan4yin/nixos-licheepi4a/blob/0fb4b65137de445de543ed8532d4aac6ecc27271/flake.nix)

There is also a pre-existing evaluation/build hazard: the pinned LP4A flake exposes
`pkgsKernelCross` and `pkgsKernelNative` only under `packages.x86_64-linux`, while the local RISC-V
host wiring accesses `packages.${system}.pkgsKernelCross` with `system = "riscv64-linux"`. This
reference is latent until forced; it is not evidence of a kernel regression and is not fixed by
mainline support alone. A migration should choose a consistent native or cross-build package set and
evaluate the full host derivation before attempting a system build.
[Pinned exports](https://github.com/ryan4yin/nixos-licheepi4a/blob/0fb4b65137de445de543ed8532d4aac6ecc27271/flake.nix)
[Local lookup](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/outputs/riscv64-linux/src/rolling-girls-nozomi.nix#L44)
[Architecture argument](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/outputs/default.nix#L34)

### Current nixpkgs supplies useful building blocks, not an automatically validated board image

The current-nixpkgs source comparison resolves `nixos-unstable` to
**`6510408d147d8c5e6d76043e899e9251756f6a75`** at this research snapshot. Moving-branch links below
identify source locations; use this revision when reproducing the findings. This is a comparison
target, not the repository's existing lock revision.
[Pinned nixpkgs tree](https://github.com/NixOS/nixpkgs/tree/6510408d147d8c5e6d76043e899e9251756f6a75)

The live `nixos-unstable` source selects Linux **6.18** as the default package family and **7.2** as
`linux_latest`. The report's richer v7.2 peripheral evidence must not silently be assigned to the
default 6.18 kernel. Choose and test an explicit supported family; the source/configuration audit
can identify what the chosen family enables, but evaluation cannot verify hardware.
[Kernel aliases](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/top-level/linux-kernels.nix)

At this snapshot nixpkgs packages U-Boot **2026.07**, even though the upstream tag index already has
**2026.10**. Its `ubootOrangePi5Plus` combines upstream TF-A RK3588 BL31 with the rkbin DDR TPL. Its
existing `ubootVisionFive2` plus OpenSBI is a Mars firmware candidate: the shared upstream 2026.07
defconfig includes `jh7110-milkv-mars` in `OF_LIST`; the separately loaded Linux DT still needs to
be Mars-specific. This is package/source availability, not a tested Mars binary. Do not substitute
upstream 2026.10 feature claims into a nixpkgs 2026.07 artifact without checking the difference.
[U-Boot packaging](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/misc/uboot/default.nix)
[TF-A packaging](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/misc/arm-trusted-firmware/default.nix)
[Shared 2026.07 defconfig](https://github.com/u-boot/u-boot/blob/v2026.07/configs/starfive_visionfive2_defconfig)
[Mars DT selection](https://github.com/u-boot/u-boot/blob/v2026.07/doc/board/starfive/milk-v_mars.rst)

RISC-V also retains a separate build-cost problem. The current official release-supported systems
list includes `aarch64-linux`, `aarch64-darwin` and `x86_64-linux`, **not `riscv64-linux`**.
Upstream Linux support does not imply the same official package build/cache coverage as aarch64.
This is not a claim that no RISC-V substitutes exist anywhere; community caches and project builds
require their own availability/trust assessment.
[Official release systems](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/top-level/release-supported-systems.json)
[NixOS release build definition](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/release-combined.nix)

### Stock kernel configuration and DT packaging: start without a custom kernel

The bounded source audit found **no mandatory missing stock configuration gate for basic storage and
wired Ethernet** on the three SoC families. Prefer standard `pkgs.linuxPackages` (6.18.55 in this
snapshot) or `pkgs.linuxPackages_latest` (7.2.9), the actual board DTB and an appropriate initrd
before introducing `structuredExtraConfig`, extra patches or a different defconfig. Those changes
produce a different kernel derivation and usually lose substitution for that kernel and its
dependent modules; ordinary userspace need not change. Actual cache objects were not queried.
[Pinned aliases](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/pkgs/top-level/linux-kernels.nix)
[Version metadata](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/pkgs/os-specific/linux/kernel/kernels-org.json)

This is a **source-derived candidate assessment**, not a generated `.config` or a successful
build/boot. Nixpkgs starts from architecture defconfig plus common settings, with
`autoModules = true` and `preferBuiltin = true` on these architectures. Its generator still chooses
modules for reachable tristate drivers unless preserving an existing builtin; non-default boolean
options are not automatically enabled. The selected 6.18.55/7.2.9 architecture defconfigs preserve
the important SoC/controller seeds below.
[Generic builder](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/pkgs/os-specific/linux/kernel/generic.nix#L34)
[Config generator](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/pkgs/os-specific/linux/kernel/generate-config.pl#L94)
[arm64 stable defconfig](https://github.com/gregkh/linux/blob/v7.2.9/arch/arm64/configs/defconfig)
[RISC-V stable defconfig](https://github.com/gregkh/linux/blob/v7.2.9/arch/riscv/configs/defconfig)

| Board            | Basic upstream controller paths                                                                                                                          | Migration implication                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Orange Pi 5 Plus | Rockchip DesignWare MMC for SD; SDHCI/DWCMSHC for eMMC; Rockchip DesignWare PCIe and PHYs for NVMe and both RTL8125 Ethernet ports; `R8169` for Ethernet | Ethernet uses separate **PCIe NICs**, not the SoC DWMAC path. The seeds/dependencies are available; some PHY and NVMe/NIC drivers are modular. [Board DT][opi-dt] [MMC Kconfig](https://github.com/torvalds/linux/blob/v7.2/drivers/mmc/host/Kconfig) [PCIe Kconfig](https://github.com/torvalds/linux/blob/v7.2/drivers/pci/controller/dwc/Kconfig) [Realtek gates](https://github.com/torvalds/linux/blob/v7.2/drivers/net/ethernet/realtek/Kconfig)                   |
| Milk-V Mars      | StarFive DesignWare MMC, DWMAC StarFive, Motorcomm PHY and StarFive clock/reset/pinctrl                                                                  | Shared JH7110 controller support is present, but apply the **Mars** DT for its PHY delays and wiring. Mars explicitly sets `usb0` to host mode; VisionFive 2 revision DT names and its USB role caveats must not be transferred to Mars. [Mars DT][mars-dt] [Common DT][jh-common] [SoC gates](https://github.com/torvalds/linux/blob/v7.2/arch/riscv/Kconfig.socs) [MAC gates](https://github.com/torvalds/linux/blob/v7.2/drivers/net/ethernet/stmicro/stmmac/Kconfig) |
| Lichee Pi 4A     | `ARCH_THEAD`, TH1520 pinctrl/AP clock, SDHCI/DWCMSHC matching `thead,th1520-dwcmshc`, and `DWMAC_THEAD`                                                  | eMMC, SD and both MACs are enabled by the module DT. No extra TH1520 pinctrl or AP-clock boolean override was identified. [Module DT][lpi-module] [DWCMSHC match](https://github.com/torvalds/linux/blob/v7.2/drivers/mmc/host/sdhci-of-dwcmshc.c) [Clock defaults](https://github.com/torvalds/linux/blob/v7.2/drivers/clk/thead/Kconfig)                                                                                                                               |

The controller-level stock configuration finding does **not** make Mars's LTS and latest DT behavior
identical. Mars v7.2/v7.2.9 adds explicit eMMC HS200/supply/reset-pinctrl properties and SD
card-detect/disable-write-protect wiring that are absent from the inspected v6.18.55 Mars DTS,
although the common DTS enables the underlying controllers. Prefer the newer DT/kernel pair when
those properties matter, or validate the exact LTS behavior on the actual boot medium. Mars's
explicit USB host mode is present in the inspected board DTs; no VisionFive 2 peripheral-role
caution is inferred for it.
[Mars v7.2.9 DT](https://github.com/gregkh/linux/blob/v7.2.9/arch/riscv/boot/dts/starfive/jh7110-milkv-mars.dts)
[Mars v6.18.55 DT](https://github.com/gregkh/linux/blob/v6.18.55/arch/riscv/boot/dts/starfive/jh7110-milkv-mars.dts)

Nixpkgs defaults `buildDTBs` to true for both aarch64 and RISC-V, builds `dtbs` and installs them
under the kernel output's `dtbs` directory. The board Makefiles include the OPi 5 Plus, Mars and
LP4A DTBs under the enabled architecture gates. NixOS's device-tree module defaults to the kernel
DTB directory and provides `hardware.deviceTree.name`. **Producing the correct DTB and passing it
from firmware remain different steps**; verify the selected firmware's actual DT/ACPI mode and
memory/reservation fixups.
[Kernel DTB build/install](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/pkgs/os-specific/linux/kernel/build.nix#L79)
[NixOS DT module](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/nixos/modules/hardware/device-tree.nix#L124)
[Rockchip Makefile](https://github.com/torvalds/linux/blob/v7.2/arch/arm64/boot/dts/rockchip/Makefile)
[StarFive Makefile](https://github.com/torvalds/linux/blob/v7.2/arch/riscv/boot/dts/starfive/Makefile)
[T-Head Makefile](https://github.com/torvalds/linux/blob/v7.2/arch/riscv/boot/dts/thead/Makefile)

For OPi stage1 NVMe/encrypted-root or early networking, check independently DT-probed PHY
dependencies: `phy-rockchip-naneng-combphy` is modular in the seed and may need explicit initrd
inclusion for the actual link; `phy-rockchip-usbdp` matters for required early USB. A module's
dependency closure need not pull in independent platform/PHY devices. `PCIE_ROCKCHIP_DW_HOST` and
the PCIe3 PHY are seeded builtin, so do not request a nonexistent host `.ko`. Add `r8169` to stage1
only if early wired networking is required. JH7110 AON/STG clock drivers can also be modular. These
are migration checks, **not a diagnosed cause of an observed boot failure**; initrd inclusion can
preserve the stock kernel derivation.
[Rockchip module names](https://github.com/torvalds/linux/blob/v7.2/drivers/phy/rockchip/Makefile)
[StarFive clocks](https://github.com/torvalds/linux/blob/v7.2/drivers/clk/starfive/Kconfig)

For TH1520 noncoherent DMA, stock `ARCH_THEAD` selects the T-Head errata framework; MAE/CMO default
on, and CMO selects the noncoherent/cache-operation machinery implemented by the upstream T-Head
code. Preserve them if deliberately reducing the kernel. No mandatory stock `DCACHE_WORD_ACCESS=n`
override was found: efficient unaligned access is a nonportable opt-in rather than a stock
requirement. Do not copy a vendor workaround into a new custom kernel without demonstrating the
relevant setting. Standard RISC-V vector support is runtime-detected; it does not imply TH1520's
nonstandard `xtheadvector` is ratified RVV 1.0 or provides usable vendor-vector acceleration.
[Errata defaults](https://github.com/torvalds/linux/blob/v7.2/arch/riscv/Kconfig.errata)
[Cache operations](https://github.com/torvalds/linux/blob/v7.2/arch/riscv/errata/thead/errata.c)
[Unaligned/vector gates](https://github.com/torvalds/linux/blob/v7.2/arch/riscv/Kconfig) [TH1520 ISA
DT][th-soc]

The LP4A USB limitation survives the exact-release check: the full board/module/SoC DT chain has no
USB controller or PHY nodes in inspected **v7.2**, **v7.2.9** and **v6.18.55** sources. Enabling
generic DWC3/xHCI cannot instantiate that missing board path. Porting matched vendor
DT/glue/PHY/clock support is separate work. Wi-Fi is a separate current-host requirement: both local
LP4A hosts enable wireless, but their actual chip was not identified here. SDIO and power sequencing
alone do not establish working Wi-Fi. Identify the installed chip, its driver and firmware and test
preservation; **if it is AIC8800**, the inspected upstream wireless vendor Kconfig lacks that driver
family and downstream support may need to remain. Do not generalize this conditional finding to
every LP4A Wi-Fi variant.
[Stable TH1520 SoC DT](https://github.com/gregkh/linux/blob/v7.2.9/arch/riscv/boot/dts/thead/th1520.dtsi)
[LTS TH1520 SoC DT](https://github.com/gregkh/linux/blob/v6.18.55/arch/riscv/boot/dts/thead/th1520.dtsi)
[Wireless gates](https://github.com/torvalds/linux/blob/v7.2/drivers/net/wireless/Kconfig)
[Nozomi wireless](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/hosts/rolling-girls-nozomi/default.nix#L30)
[Yukina wireless](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/hosts/rolling-girls-yukina/default.nix#L30)

The source audit also found stock arm64 KVM, bridge and ordinary reachable TUN/vhost plumbing as a
credible OPi microVM baseline. It does not establish that firmware enters Linux with the necessary
EL2 state, that PCIe is stable, or that encrypted-root stage1 works. Check the actual resulting
kernel configuration, selected DTB and initrd before hardware acceptance.
[arm64 defconfig](https://github.com/gregkh/linux/blob/v7.2.9/arch/arm64/configs/defconfig)

### Existing checks have different guarantees

`just test` evaluates the repository's `evalTests`. The root result is a boolean aggregation of
per-architecture empty-failure sets; the aarch64 kernel test only checks that `boot.kernelPackages`
is non-null. It neither builds the kernel nor validates its DT, initrd, firmware or boot. The
repository already provides `just eval-host <host>` to force the full host derivation and
`just build-host <host>` to build the closure without activating it. Those checks are appropriate
during a future implementation, followed by the actual hardware acceptance checks; none was run for
this documentation-only change.
[Recipes](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/Justfile#L21)
[Kernel test](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/outputs/aarch64-linux/tests/kernel/expr.nix#L5)
[Root test aggregation](https://github.com/ryan4yin/nixos-config-sbc/blob/80b739f2058321cc755157ed77fb1f1568cc6204/outputs/default.nix#L103)

## Primary sources

[kernel-releases]: https://www.kernel.org/
[uboot-tags]: https://api.github.com/repos/u-boot/u-boot/tags?per_page=5
[uboot-tag]: https://api.github.com/repos/u-boot/u-boot/git/ref/tags/v2026.10
[edk2-release]: https://github.com/tianocore/edk2/releases/tag/edk2-stable202608
[rk-edk-release]: https://github.com/edk2-porting/edk2-rk3588/releases/tag/v1.1
[opi-dt]:
  https://github.com/torvalds/linux/blob/v7.2/arch/arm64/boot/dts/rockchip/rk3588-orangepi-5-plus.dts
[opi-common]:
  https://github.com/torvalds/linux/blob/v7.2/arch/arm64/boot/dts/rockchip/rk3588-orangepi-5.dtsi
[opi-uboot]: https://github.com/u-boot/u-boot/blob/v2026.10/configs/orangepi-5-plus-rk3588_defconfig
[rockchip-guide]: https://docs.u-boot.org/en/latest/board/rockchip/rockchip.html
[tfa-rk3588]:
  https://github.com/ARM-software/arm-trusted-firmware/blob/v2.14.0/plat/rockchip/rk3588/platform.mk
[panthor-fw]: https://github.com/torvalds/linux/blob/v7.2/drivers/gpu/drm/panthor/panthor_fw.c
[rk-edk-readme]: https://github.com/edk2-porting/edk2-rk3588/blob/master/README.md
[mars-dt]:
  https://github.com/torvalds/linux/blob/v7.2/arch/riscv/boot/dts/starfive/jh7110-milkv-mars.dts
[jh-common]:
  https://github.com/torvalds/linux/blob/v7.2/arch/riscv/boot/dts/starfive/jh7110-common.dtsi
[mars-uboot]: https://github.com/u-boot/u-boot/blob/v2026.10/doc/board/starfive/milk-v_mars.rst
[jh-uboot]: https://github.com/u-boot/u-boot/blob/v2026.10/doc/board/starfive/jh7110_common.rst
[jh-ddr]: https://github.com/u-boot/u-boot/blob/v2026.10/drivers/ram/starfive/starfive_ddr.c
[lpi-dt]:
  https://github.com/torvalds/linux/blob/v7.2/arch/riscv/boot/dts/thead/th1520-lichee-pi-4a.dts
[lpi-module]:
  https://github.com/torvalds/linux/blob/v7.2/arch/riscv/boot/dts/thead/th1520-lichee-module-4a.dtsi
[th-soc]: https://github.com/torvalds/linux/blob/v7.2/arch/riscv/boot/dts/thead/th1520.dtsi
[lpi-uboot-guide]: https://github.com/u-boot/u-boot/blob/v2026.10/doc/board/thead/lpi4a.rst
[lpi-uboot]: https://github.com/u-boot/u-boot/blob/v2026.10/configs/th1520_lpi4a_defconfig
[th-ddr-mail]: https://lists.u-boot-project.org/pipermail/u-boot/2025-May/589631.html
[th-fw]: https://github.com/ziyao233/th1520-firmware/blob/master/README.md
[edk-platforms]: https://api.github.com/repos/tianocore/edk2-platforms/contents/Platform
[edk-silicon]: https://api.github.com/repos/tianocore/edk2-platforms/contents/Silicon
[edk-riscv]: https://api.github.com/repos/tianocore/edk2-platforms/contents/Platform/RISC-V
