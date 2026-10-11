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

The Orange Pi hosts use the explicitly selected `nixos-26.05` input and the local
[`orangepi5plus` module](./nixos/boards/orangepi5plus.nix), with `linuxPackages_latest` rather than
the default kernel family. Tagged and revision-pinned inputs retain explicit references; MicroVM and
tooling package sets keep their separate unstable inputs. Boot firmware is provisioned separately
and is not rebuilt by ordinary system updates.

## Orange Pi boot requirements

The existing boot path is EDK2 -> EFI GRUB -> Linux. In EDK2's **ACPI / Device Tree** settings,
select **Config Table Mode = Device Tree** and **Device Tree Compatibility Mode = Mainline**. Verify
the installed firmware version and board settings before activation. For the bundled firmware-DT
path, disable **Support DTB override & overlays**: an earlier installation may have left a vendor
DTB at the ESP path `dtb/base/rk3588-orangepi-5-plus.dtb`. Selecting Mainline alone does not
establish that this old override is unused. Retain the old file/settings for recovery; any
deliberately retained override must be verified as compatible with the mainline kernel.

Stock NixOS GRUB does not load `hardware.deviceTree.name`: that setting selects the DTB built with
the kernel, while this configuration boots with the DT supplied and fixed up by EDK2. It does not
promise a different DTB for each GRUB generation. This preserves firmware runtime fixups and avoids
a local GRUB installer patch. See the
[EDK2 DT configuration](https://github.com/edk2-porting/edk2-rk3588#device-tree-configuration),
[DTB override documentation](https://github.com/edk2-porting/edk2-rk3588#custom-device-tree-blob-dtb-override-and-overlays)
and the [upstream DT ABI](https://docs.kernel.org/devicetree/bindings/ABI.html).

The NVMe encryption and USB-key layout are preserved. The board module adds early USB/PHY modules so
the initrd can discover the key and storage. The systemd initrd uses `keyFileTimeout = 10` to wait
for the USB key before falling back to a password; the obsolete explicit `fallbackToPassword`
setting is removed.

Before switching from a vendor DT mode, record the current firmware settings. Booting an old
vendor-kernel generation may also require restoring its previous firmware DT mode; keeping its GRUB
entry alone does not establish a working rollback.

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

## Why a separate repository for SBCs?

The SBC configurations keep their own input lock and board settings so their upgrade and hardware
validation cycle can be managed independently from `ryan4yin/nix-config`. The current Orange Pi
configuration uses standard nixpkgs kernels rather than a vendor kernel flake.

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
