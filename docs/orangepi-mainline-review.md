# Orange Pi 5 Plus: lessons from the old RK3588 port

## Scope and decision

Keep the stock nixpkgs kernel and the existing EDK2 -> EFI GRUB boot path. The useful lessons from
the old port are its explicit boot dependencies, serial diagnostics, and attention to the device
tree actually handed to Linux. Its vendor kernel configuration, forced initrd restrictions, and
board-specific workaround proposals should not be copied wholesale.

This review compares the old input locked in the repository before migration,
`ryan4yin/nixos-rk3588@fc13924f014d9d7961d1865ecaf388ba25d37f14`, with the migrated
[board module](../nixos/boards/orangepi5plus.nix), and the maintained fork
`gnull/nixos-rk3588@2a1add82960dda2e0d203051dcf1ae4c1bc8452c`. The original repository's current
default commit, `37ca2142a3c6e99e3a4145d235e1e80928c9195a`, changes only the README to point to that
fork. The fork is 15 commits ahead of the old input on its own history.
[Original latest commit](https://github.com/ryan4yin/nixos-rk3588/commit/37ca2142a3c6e99e3a4145d235e1e80928c9195a),
[fork comparison](https://github.com/ryan4yin/nixos-rk3588/compare/fc13924f014d9d7961d1865ecaf388ba25d37f14...gnull:main).

The initial source-audit baseline was nixpkgs `6510408d147d8c5e6d76043e899e9251756f6a75`, selecting
Linux **7.2.9**. The implemented release input is now `nixos-26.05` at
`7c8764b7c7b09b34f632464276218ef9090eaa11`; evaluation confirms its `linuxPackages_latest` is also
**7.2.9**, while the default family is **6.18.55**. The initial audit confirmed no explicit host
governor override and `hardware.ksm.enable = true` on `suzu`. Its standard kernel configuration
requests `CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`, `KSM=y`, `CGROUPS=y`, `MEMCG=y`, and
`CMA_SIZE_MBYTES=32`. These are builder configuration requests, not measurements of a running board.
The source comparison also uses upstream v7.2 DT files and the exact v7.2.9 arm64 defconfig. A
generated final `.config` and real firmware handoff were not read in this review.
[Kernel selection](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/pkgs/top-level/linux-kernels.nix),
[common configuration](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/pkgs/os-specific/linux/kernel/common-config.nix),
[7.2.9 arm64 defconfig](https://github.com/gregkh/linux/blob/v7.2.9/arch/arm64/configs/defconfig).

This is a source and configuration review. It does not establish cold boot, actual CPU clocks, fan
behavior, Ethernet throughput, EL2/KVM availability, or encrypted-root unlock on hardware.

## 1. Check historical firmware DT overrides before the first mainline boot

This is the most concrete migration lesson. The old
[UEFI guide](https://github.com/ryan4yin/nixos-rk3588/blob/fc13924f014d9d7961d1865ecaf388ba25d37f14/UEFI.md)
instructed users to set `Config Table Mode = Both` and enable `Support DTB override & overlays`. Its
[raw EFI image module](https://github.com/ryan4yin/nixos-rk3588/blob/fc13924f014d9d7961d1865ecaf388ba25d37f14/modules/rk3588-raw-efi.nix)
copied raw kernel DTBs to `/boot/dtb/base` during bootloader installation.

For this board, that can leave `rk3588-orangepi-5-plus.dtb` at partition-relative
`\dtb\base\rk3588-orangepi-5-plus.dtb`. Current EDK2 can also search `\dtb`, `\dtb\rockchip`, and
user-configured preferred paths. Removing the old flake does not remove files previously copied to
the ESP or change firmware variables. Therefore, **if overrides remain enabled and a historical
vendor DTB remains on the selected boot device, selecting Mainline mode alone may still use that
override**. This is a conditional risk, not evidence that such a file is present on either host.
[EDK2 DT override search and platform names](https://github.com/edk2-porting/edk2-rk3588#custom-device-tree-blob-dtb-override-and-overlays).

The minimal preparation is to record the installed firmware version and previous settings, inspect
override locations, and use `Config Table Mode = Device Tree` with `Mainline` compatibility. Disable
historical overrides when using the firmware DT, or separately validate an intentionally supplied
mainline-compatible override. Keep the previous settings available for vendor-kernel recovery. No
automated file removal or firmware change is warranted by this source review.
[EDK2 configuration](https://github.com/edk2-porting/edk2-rk3588#device-tree-configuration).

Both host installation guides now point to the
[current repository boot requirements](../README.md#orange-pi-boot-requirements) and canonical EDK2
instructions, including the historical override check.

### What the maintained fork fixed, and why it is not a drop-in improvement here

Two merged fork commits fix real problems in the vendor-DT workflow:

- [35a5ab8](https://github.com/gnull/nixos-rk3588/commit/35a5ab8f8ae5aea681b2a208bfd18331bd206110)
  copies the processed `hardware.deviceTree.package`, rather than raw kernel DTBs, so configured
  overlays are included.
- [92af9a9](https://github.com/gnull/nixos-rk3588/commit/92af9a9fa2c4c3d205e74166ce0c089e9a222a8c)
  moves the copy hook into ordinary board rebuilds rather than image creation alone.

Their remaining shared directory can still be overwritten by the newest installed generation. Open
[fork issue #1](https://github.com/gnull/nixos-rk3588/issues/1) describes precisely that limitation.
Open [PR #20](https://github.com/gnull/nixos-rk3588/pull/20), inspected at head
`3605ef2f12e0a1c60ae48d1131f340110c76d87f`, proposes systemd-boot plus `installDeviceTree = true`
for per-generation DTBs. It was **not merged** at the time of review. Its own documentation leaves
historical override files untouched and keeps the shared-copy hook for GRUB configurations.
[Proposed files](https://github.com/gnull/nixos-rk3588/pull/20/files).

The lesson worth borrowing is to make the active DT contract explicit and preserve rollback
information. The current migration retains stock GRUB and requires a compatible upstream-derived
firmware DT, whose actual handoff still needs hardware validation. EDK2 applies PCIe/SATA/USB
runtime fixups to that DT; a loader-supplied DT may bypass firmware processing. The upstream DT ABI
permits compatible older DTs with newer kernels, so matching every DTB to every kernel generation is
not by itself a reason to change loaders. A loader change would require its own fixup and rollback
validation.
[EDK2 fixup note](https://github.com/edk2-porting/edk2-rk3588#custom-device-tree-blob-dtb-override-and-overlays),
[DT ABI](https://docs.kernel.org/devicetree/bindings/ABI.html).

## 2. Keep the new early USB/PHY dependencies; do not restore the old forced initrd list

The old
[base module](https://github.com/ryan4yin/nixos-rk3588/blob/fc13924f014d9d7961d1865ecaf388ba25d37f14/modules/boards/base.nix)
used `mkForce false` for `includeDefaultModules` and a forced short `availableKernelModules` list
because its custom kernel lacked some NixOS default modules. Merged
[original PR #25](https://github.com/ryan4yin/nixos-rk3588/pull/25), dated 2024-03-24, shows that
the change was an initrd inclusion workaround, despite its blacklist-oriented title. It was not a
general blacklist of bad RK3588 hardware drivers.

That workaround should stay removed for a stock kernel. The root remains encrypted NVMe, while the
raw key and password keyboard need USB before root mount. Independently DT-probed PHYs can be needed
before the NVMe or USB endpoint exists. The current thin board module names the Naneng combo PHY and
USB/DP PHY alongside USB host controllers; host hardware modules retain NVMe, HID, and USB storage.
This expresses the actual early-boot requirement without replacing the kernel build.
[Current board module](../nixos/boards/orangepi5plus.nix),
[Rockchip PHY Kconfig](https://github.com/torvalds/linux/blob/v7.2/drivers/phy/rockchip/Kconfig),
[PHY module names](https://github.com/torvalds/linux/blob/v7.2/drivers/phy/rockchip/Makefile).

The migration has also fixed a separate systemd-initrd requirement: `keyFileTimeout = 10` provides a
bounded wait for the raw USB key device before password fallback. That is more relevant to this boot
path than copying the old module restrictions. The source of truth for this contract is the
generated crypttab and systemd generator behavior.
[NixOS LUKS module](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/nixos/modules/system/boot/luksroot.nix),
[systemd keyfile timeout](https://www.freedesktop.org/software/systemd/man/latest/crypttab.html#keyfile-timeout=).

## 3. Preserve standard power and memory policy until measurements show a problem

The old vendor config had `CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y`, while its NixOS base selected
`ondemand`. The current standard nixpkgs kernel requests `schedutil`; the host leaves
`powerManagement.cpuFreqGovernor = null`, so there is no explicit NixOS override. Copying `ondemand`
would change policy without evidence that it improves this workload. Compare idle power, sustained
VM/build performance, frequencies, temperatures, and throttling after a successful boot before
adding a governor setting.
[Old vendor config](https://github.com/ryan4yin/nixos-rk3588/blob/fc13924f014d9d7961d1865ecaf388ba25d37f14/pkgs/kernel/rk35xx_vendor_config),
[nixpkgs default](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/pkgs/os-specific/linux/kernel/common-config.nix#L125),
[CPUFreq governor behavior](https://docs.kernel.org/admin-guide/pm/cpufreq.html).

The upstream board includes a PWM fan with cooling levels and thermal cooling maps. Its OPP tables,
CPU supplies and thermal zones provide kernel-managed policy. The exact 7.2.9 arm64 seed enables
`CPUFREQ_DT`, Rockchip PWM, PWM-fan support and Rockchip thermal support. This supports testing the
standard path before adding a custom fan daemon, thermal overlay or vendor CPU-frequency driver. The
active firmware DT must describe equivalent working nodes; the kernel's packaged DT alone does not
prove that.
[Board shared DT](https://github.com/torvalds/linux/blob/v7.2/arch/arm64/boot/dts/rockchip/rk3588-orangepi-5.dtsi),
[Plus fan PWM](https://github.com/torvalds/linux/blob/v7.2/arch/arm64/boot/dts/rockchip/rk3588-orangepi-5-plus.dts#L119),
[OPP tables](https://github.com/torvalds/linux/blob/v7.2/arch/arm64/boot/dts/rockchip/rk3588-opp.dtsi),
[7.2.9 seed](https://github.com/gregkh/linux/blob/v7.2.9/arch/arm64/configs/defconfig).

KSM is already enabled in the current `suzu` configuration and requested by the standard kernel.
Merged [original PR #27](https://github.com/ryan4yin/nixos-rk3588/pull/27), dated 2024-03-24, added
it to the vendor kernel for microvm.nix. This is a useful compatibility check, not a missing
optimization to add again. Any more aggressive KSM tuning should follow measured page-sharing
benefit and CPU cost for the actual guests.

The old config also explicitly disabled memory compaction and used a 16 MiB default CMA area; the
new common config requests 32 MiB. These are not reusable tuning recommendations. The old UEFI
guide's manual `compact_memory` suggestion concerns image-build allocation failures, and open
[fork issue #13](https://github.com/gnull/nixos-rk3588/issues/13) remains an unresolved emulated
image-build report, including a report of failure on a 32 GiB host. It does not establish a board
RAM limit or justify changing host overcommit, dropping caches, or disabling compaction.

There is a separate potential power/performance difference: the vendor config enables
`ARM_ROCKCHIP_DMC_DEVFREQ`, while the inspected upstream devfreq Kconfig offers
`ARM_RK3399_DMC_DEVFREQ`, not an equivalent generic RK3588 DMC DVFS driver. Upstream RK3588 has a
DFI monitoring node; that is not itself a DDR frequency-scaling implementation. Measure memory
bandwidth and idle power before promising vendor-equivalent DDR DVFS. Carrying that downstream
driver would expand kernel and firmware maintenance, so it is not a low-cost default optimization.
[Vendor config](https://github.com/ryan4yin/nixos-rk3588/blob/fc13924f014d9d7961d1865ecaf388ba25d37f14/pkgs/kernel/rk35xx_vendor_config),
[upstream devfreq Kconfig](https://github.com/torvalds/linux/blob/v7.2/drivers/devfreq/Kconfig),
[RK3588 DFI node](https://github.com/torvalds/linux/blob/v7.2/arch/arm64/boot/dts/rockchip/rk3588-base.dtsi#L2178).

## 4. Keep serial diagnostics; treat Ethernet and accelerator workarounds by exact hardware

The old Plus module's `rootwait` and serial console at `ttyS2,1500000` remain useful and are
retained. Its `earlycon` is worth keeping as a documented temporary GRUB argument for the first
hardware boot or an early hang, rather than assuming the normal console captures failures before
console registration. The upstream board specifies `stdout-path = "serial2:1500000n8"`, which
supports the intended diagnostic path when the firmware DT preserves it. `consoleblank=0` is a
screen usability choice, not a performance optimization.
[Old Plus module](https://github.com/ryan4yin/nixos-rk3588/blob/fc13924f014d9d7961d1865ecaf388ba25d37f14/modules/boards/orangepi5plus.nix),
[upstream chosen node](https://github.com/torvalds/linux/blob/v7.2/arch/arm64/boot/dts/rockchip/rk3588-orangepi-5.dtsi#L20),
[kernel parameters](https://docs.kernel.org/admin-guide/kernel-parameters.html).

The old `cgroup_enable=cpuset`, `cgroup_memory=1`, `cgroup_enable=memory`, and `swapaccount=1` block
was copied from Armbian and labeled as Docker optimization. The standard kernel already requests
cgroup and memory-controller support, and the architecture seed includes CPU sets. No missing
controller was demonstrated here. Keep that block removed; verify the desired controllers after boot
rather than reintroducing legacy flags.
[Standard common config](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/pkgs/os-specific/linux/kernel/common-config.nix),
[7.2.9 seed](https://github.com/gregkh/linux/blob/v7.2.9/arch/arm64/configs/defconfig),
[cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html).

The Plus uses two PCIe RTL8125 Ethernet controllers. The old vendor config already enabled
`R8169=m`; the exact 7.2.9 seed also enables it. The upstream Plus DT enables the separate PCIe
links. There is no evidence here requiring an out-of-tree `r8125` package, forced PCIe downgrade,
forced 100 Mbps advertisement, or a DWMAC-specific workaround. On hardware, check both port
identities, negotiated speed, errors and sustained throughput, and confirm configured interface
names still match the discovered devices.
[Old config](https://github.com/ryan4yin/nixos-rk3588/blob/fc13924f014d9d7961d1865ecaf388ba25d37f14/pkgs/kernel/rk35xx_vendor_config),
[7.2.9 seed](https://github.com/gregkh/linux/blob/v7.2.9/arch/arm64/configs/defconfig),
[Plus PCIe links](https://github.com/torvalds/linux/blob/v7.2/arch/arm64/boot/dts/rockchip/rk3588-orangepi-5-plus.dts#L275).

Closed [fork PR #14](https://github.com/gnull/nixos-rk3588/pull/14) was **not merged**. Its 100 Mbps
workaround concerns Orange Pi **5 Pro**, a Motorcomm **YT6801**, and an author's reported PoE/NVMe
setup. Its claimed board signal-integrity cause is not a demonstrated fact about Orange Pi 5 Plus.
Do not apply that proposal to these RTL8125 ports.

## 5. Borrow the fork's upstream example and maintenance lessons, not its default vendor kernel

The fork contains a merged
[upstream-only Plus example](https://github.com/gnull/nixos-rk3588/tree/2a1add82960dda2e0d203051dcf1ae4c1bc8452c/examples/upstream-opi).
It uses `linuxPackages_latest` and the nixpkgs `ubootOrangePi5Plus` package, without depending on
the port flake. That reinforces the present stock-kernel direction. Its SD-card/extlinux layout is a
distinct installation design; it is not a reason to replace an existing encrypted-NVMe EFI
installation.

The fork's main board path remains vendor Linux **6.1.115**. Merged
[PR #12](https://github.com/gnull/nixos-rk3588/pull/12), dated 2026-03-02, switches to Armbian's
vendor branch, removes a separate Panthor patch already included there, and adds a Mali vendor-build
path correction. Earlier commit
[0088c8e](https://github.com/gnull/nixos-rk3588/commit/0088c8e75db0b47c5cac024f429dc42ab29fec46)
tried stock Linux 6.15;
[0e582aa](https://github.com/gnull/nixos-rk3588/commit/0e582aae7b8c183bdfbb73b335d661405b2e110c)
reverted it following [issue #4](https://github.com/gnull/nixos-rk3588/issues/4). That issue reports
application incompatibility around vendor RKNPU interfaces. It does not establish that headless
NVMe, Ethernet, or KVM require the vendor kernel, nor prove the present mainline NPU ABI supports
vendor applications.

Open [PR #19](https://github.com/gnull/nixos-rk3588/pull/19) proposes proprietary Mali OpenCL
support for uses such as Jellyfin tone mapping. It is separate optional application support, not a
prerequisite for these servers. The old port's Panthor patch should not be added to a kernel whose
upstream seed already enables Panthor. Add GPU/NPU userland only when a concrete workload and its
ABI requirements are in scope.

Merged [original PR #64](https://github.com/ryan4yin/nixos-rk3588/pull/64), dated 2024-12-07,
vendors a patch after GitHub's generated patch representation changed and invalidated its hash. The
general lesson is reproducible source inputs. The current stock kernel avoids that patch source
entirely. [Original issue #58](https://github.com/ryan4yin/nixos-rk3588/issues/58) documents a
vendor-kernel compiler failure and a pin/revert recovery; open
[issue #69](https://github.com/ryan4yin/nixos-rk3588/issues/69) asks for a cache. Stock nixpkgs
kernels preserve the standard package derivation and cache opportunities, avoiding a separate
long-lived kernel compiler pin.
[Generic kernel builder](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/pkgs/os-specific/linux/kernel/generic.nix).

Open [PR #17](https://github.com/gnull/nixos-rk3588/pull/17) proposes dropping
nixos-generators/specialArgs and exporting internal packages. It is unmerged housekeeping for that
flake, not a missing feature in this repository after removing the dependency.

## 6. Reuse nix-config's selective terminal databases

The [shared SSH module](../nixos/base/ssh.nix) now follows nix-config's existing selection of
`ghostty.terminfo` and `kitty.terminfo`. It leaves `environment.enableAllTerminfo` disabled. The
previous all-terminal option pulled terminfo outputs from 13 packages in the investigated nixpkgs
revision, including Contour's full Qt/C++ build. That build took 11 minutes 25 seconds and exposed a
GCC 16 SIMD incompatibility during the initial migration.

The selective set removes Contour from Mitsuha's package dependency graph, so its local compiler
workaround is removed. No new terminfo builder is needed. The selected packages still build under
their normal nixpkgs recipes; this change reduces unrelated package choices, not every terminal
build cost.
[Terminfo module](https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/nixos/modules/config/terminfo.nix#L39),
[nix-config SSH module](https://github.com/ryan4yin/nix-config/blob/497fabbf9206d8befe2cd70aeaefb71aea332b96/modules/nixos/base/ssh.nix).

## 7. Preserve explicit input update boundaries

The root nixpkgs and Home Manager use explicit release branches, tagged dependencies keep their
latest release tags, and revision-pinned shared helpers retain explicit commits. MicroVM and tooling
nixpkgs retain their separate unstable channels. These choices preserve the repository's existing
update boundaries rather than removing version references. The Orange Pi board selects
`linuxPackages_latest` explicitly; it does not inherit nixpkgs' default kernel family.
[Input declarations](../flake.nix#L32).

## Discussion coverage and limits

All issue/PR metadata returned by the two repositories' `state=all, per_page=100` lists was
screened. Both lists were below 100 entries, so this covered all entries exposed by those endpoints
at review time. Selected full bodies, relevant comments and changed-file patches were then checked
for DT handoff, initrd, KSM, Ethernet, build/compiler/cache problems, and accelerator scope. This is
not a claim that every discussion or every comment was read.

In addition to the entries above, original
[issue #37](https://github.com/ryan4yin/nixos-rk3588/issues/37) and open
[PR #66](https://github.com/ryan4yin/nixos-rk3588/pull/66) concern vendor HDMI-RX log spam and a
proposed global driver disable. The fork's processed-DT commits are the more useful lesson: compare
the actual passed DT with the configured DT before blacklisting hardware. Mainline has its own
HDMI-RX integration, so the old vendor symptom does not establish a need to disable the mainline
driver. No new blacklist is recommended.

Useful follow-up work is a recorded firmware/DT handoff check, serial cold boot, USB-key and
missing-key password recovery, both Ethernet ports, fan/thermal behavior under the actual workload,
and KVM guest startup. Later tuning should be based on those results. No implementation, firmware,
bootloader, TPM, disk or network configuration was changed by this review.
