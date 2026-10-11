# TPM2 automatic unlock on the SBC hosts

Research snapshot: 2026-10-10. Scope: Orange Pi 5 Plus (RK3588), Milk-V Mars SBC (JH7110), and
Lichee Pi 4A (TH1520). This is a source/documentation review, not a hardware probe. No TPM
enrollment, key access, block-device operation, firmware change or host configuration edit was
performed.

## Conclusion

**None of the three stock-board configurations has an established ready-to-use TPM2 automatic-unlock
path in the inspected official hardware descriptions, upstream board device trees and selected
firmware sources.** Their published board specifications do not advertise a populated discrete TPM.
The reviewed Linux board/SoC DT chains do not describe a TPM, and an integrated fTPM was not
established in their usual firmware. This is sufficient to reject assuming PC-style TPM
availability; it is not a remotely verified claim that a particular physical host lacks
`/dev/tpmrm0` or that a board revision can never support an added TPM. [OPi specifications][opi]
[Mars specifications][mars] [LP4A specifications][lpi]

| Board            | Discrete TPM on stock hardware                                                                                | Reviewed firmware path                                                                                                                                                                                               | Practical consequence                                                                                                                                    |
| ---------------- | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Orange Pi 5 Plus | Not advertised by the official board specification; no TPM node in the inspected upstream DT chain            | The RK3588 EDK2 port supplies Secure Boot-related components, but the inspected OPi/common firmware-volume lists do not include a TPM device implementation or TCG2 driver. No usable fTPM feature was established.  | Existing EDK2 plus TrustZone/OP-TEE is not evidence that TPM2 enrollment will work. An external TPM would be a separate board/firmware integration task. |
| Milk-V Mars      | Not advertised by the official hardware specification; no TPM node in the inspected board/common/SoC DT chain | Mainline U-Boot/OpenSBI support does not itself instantiate TPM2. No board fTPM integration was established.                                                                                                         | A header-attached supported TPM is a possible engineering route, not a stock automatic-unlock feature.                                                   |
| Lichee Pi 4A     | Not advertised by the official hardware specification; no TPM node in the inspected board/module/SoC DT chain | RevyOS's 20260926 coreboot + OpenSBI + EDK2 firmware README describes DDR, AON, recovery and eMMC installation, but makes no TPM2 claim. Its firmware-source attribution remains unresolved in the earlier research. | Do not infer TPM2 availability from the new EDK2 firmware. Verify an actual device and boot measurements before designing enrollment.                    |

## Hardware and firmware evidence

The inspected upstream trees are the [OPi board and family DT][opi-dt], [Mars board/common
DT][mars-dt], and [LP4A board/module/SoC DT][lpi-dt]. A search of the downloaded include chains
found no `tpm`, `tcg` or `ftpm` declarations. Lack of a DT node alone does not rule out an
ACPI-described or TEE-enumerated TPM; the independent firmware review is therefore important.

The RK3588 EDK2 repository resolved to **be4d361435ef5727e72d0c52e2d457d7ae465c2d**. Its untruncated
own repository tree had no paths named for TPM/TCG/fTPM. The [OPi platform DSC][opi-dsc] includes
the [RK3588 platform description][rk-dsc], while [RK3588 FDF][rk-fdf] includes
[FvMainModules][fv-main]. These lists supply RNG, Hash2 and conditional Secure Boot
configuration/default-key components, but do not list `Tcg2Dxe` or a platform TPM device backend.
The common [Rockchip DSC][rockchip-dsc] does select `DxeTpmMeasurementLib` when Secure Boot is
enabled, and a null measurement library otherwise; it also uses `PeilessSecMeasureLibNull`. **The
measurement library reference is not a TPM implementation, and Secure Boot support is not proof of
working TPM/PCR measurement.** Submodule code naturally contains generic TPM libraries; mere library
availability does not establish that the OPi firmware instantiates them.

Linux separately defines a [TEE fTPM driver][tpm-kconfig] that depends on both TEE and OP-TEE, and a
[Microsoft fTPM binding][ftpm-binding]. These are interfaces to a firmware TPM implementation.
RK3588's TrustZone capability, TF-A and an OP-TEE image do not by themselves supply that
implementation or its persistent TPM state. No supported turnkey OPi fTPM combination was
established by this bounded review.

The [RevyOS 20260926 release README][revyos] states coreboot + OpenSBI + EDK2 and native coreboot
DDR initialization, but does not claim TPM2, fTPM, TCG2 or measured boot. Treat those features as
unverified rather than deducing them from component names.

## External TPM2 is possible, but adds maintenance work

Upstream Linux supports discrete TPM2 devices over ordinary SPI and I2C. The [SPI
binding][spi-binding] includes examples such as Infineon SLB9670 with `tcg,tpm_tis-spi`; the [I2C
binding][i2c-binding] includes recent generic PTP devices such as SLB9673/NPCT75x. Corresponding
driver families are `tpm_tis_spi` and `tpm_tis_i2c`. These bindings make a custom integration
technically credible, without demonstrating a working add-on combination for any of these three
boards. [Driver Kconfig][tpm-kconfig]

For a usable add-on, choose a TPM2 module with the correct electrical interface and pinout, enable
the actual header bus/pinctrl and a matching DT/firmware device description, and include its
bus/controller/TPM drivers in stage1. A PC motherboard's TPM connector and an SBC's 40-pin GPIO
header are not interchangeable simply because both carry SPI signals. For boot-state-bound unlock,
the firmware/loader must also actually initialize and measure the chosen boot chain into the TPM
before unlocking. A TPM discovered only after the kernel starts can provide sealing operations, but
does not retroactively create trustworthy firmware/Secure Boot measurements. This is why a generic
Linux TPM driver alone is insufficient for the intended low-maintenance trusted-boot workflow.
[SPI/I2C bindings][spi-binding] [PCR definitions][cryptenroll]

Adding a discrete TPM therefore increases board-specific DT, wiring and firmware support
obligations—the same kind of extra integration the mainline migration is trying to reduce. It should
remain a separate optional project, not a prerequisite for completing the current kernel/input
upgrade.

## NixOS/systemd can use TPM2 once the platform provides it

The selected nixpkgs revision **6510408d147d8c5e6d76043e899e9251756f6a75** includes systemd initrd
TPM2 integration. [Its module][nixos-tpm] provides `boot.initrd.systemd.tpm2.enable`, includes TPM2
userspace services/libraries, and adds generic TPM drivers. It does not create a TPM, populate a
header node or guarantee the drivers needed by an external SPI/I2C device. The current OPi boot
configuration already uses systemd initrd and LUKS2, so its software architecture can support a
future TPM2 unlock configuration. [Current OPi module](../nixos/boards/orangepi5plus.nix)
[LUKS2 layout](../hosts/12kingdoms-rakushun/disko-fs.nix)

[systemd-cryptenroll][cryptenroll] stores TPM2 enrollment metadata in a LUKS2 token and supports
unlocking through `tpm2-device=auto`; the corresponding crypttab key field is normally `none`.
Replacing the current explicit USB key path is a real configuration and enrollment migration, not
just setting a boolean. Keep a working passphrase/recovery method during any future enrollment; TPM
reset/replacement or an incompatible boot policy must not be the only path to data. No enrollment
was attempted in this research.

### PCR policy and update cost

The exact **systemd v261.3** manual says that omitting `--tpm2-pcrs` defaults to **no PCR binding**,
not implicitly PCR7. Select a deliberate policy rather than relying on older examples. [Versioned
manual source][cryptenroll-source]

| Policy                                             | Update behavior                                                                                                                             | Applicability here                                                                                                                                                                                                                                                                                                                                         |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Explicit PCR7 Secure Boot policy                   | More stable across routine kernel updates than raw firmware/kernel hashes; changes to Secure Boot mode or PK/KEK/db/dbx can still change it | Useful only when the actual firmware measures PCR7 and an enforced verified chain authenticates the intended kernel, initrd and security-relevant configuration. The current EDK2 + systemd-boot + separate initrd/firmware DT setup has not established that chain. PCR7 alone must not be presented as protecting an unauthenticated separate initrd/DT. |
| Static firmware/loader/kernel PCR values           | Updates to the measured component change the value, potentially requiring recovery and re-enrollment                                        | Poor fit for the user's aim of routine upgrades without manual maintenance unless update handling is designed explicitly.                                                                                                                                                                                                                                  |
| Signed PCR policy, commonly using PCR11 with a UKI | New signed authorized measurements can permit kernel/initrd updates without re-enrolling each LUKS volume                                   | Provides an update-friendly design, but requires a supported measured UKI/loader path and policy-signing workflow; it is additional work beyond the current mainline installation.                                                                                                                                                                         |
| No PCR binding                                     | Avoids update-induced measurement mismatch                                                                                                  | Does not bind release of the sealed secret to trusted boot state; it is not equivalent to a secure-boot-bound unattended unlock design.                                                                                                                                                                                                                    |

The systemd manual recommends certificate-based policies over brittle direct code hashes where
suitable, and explains signed policies as allowing authorized updated kernel/initrd states. Neither
that generic recommendation nor support for TPM2 userspace proves these SBCs currently implement the
necessary firmware trust chain. [PCR table and policy discussion][cryptenroll]

## Recommendation for this repository

Keep the current USB-key/password path while finishing the mainline upgrade. Do not add TPM
enrollment or remove the USB-key configuration based on SoC/EDK2 capabilities alone. When a board is
reachable, the next bounded read-only check is to inspect TPM device metadata and firmware
measured-boot/Secure Boot status (for example, `systemd-cryptenroll --tpm2-device=list`), then
decide whether an actual supported TPM exists. No such hardware observation was available during
this review.

For future hardware purchases where unattended encrypted-root boot is a priority, a platform with
documented TPM2 **and** maintained UEFI measured-boot integration is likely to have lower ongoing
cost than retrofitting these SBCs. This is an engineering recommendation based on the integration
gaps above, not a claim that the boards cannot be extended.

[opi]:
  http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-5-plus.html
[mars]: https://milkv.io/mars
[lpi]: https://wiki.sipeed.com/hardware/en/lichee/th1520/lpi4a/1_intro.html
[opi-dt]:
  https://github.com/torvalds/linux/blob/v7.2/arch/arm64/boot/dts/rockchip/rk3588-orangepi-5-plus.dts
[mars-dt]:
  https://github.com/torvalds/linux/blob/v7.2/arch/riscv/boot/dts/starfive/jh7110-milkv-mars.dts
[lpi-dt]:
  https://github.com/torvalds/linux/blob/v7.2/arch/riscv/boot/dts/thead/th1520-lichee-pi-4a.dts
[opi-dsc]:
  https://github.com/edk2-porting/edk2-rk3588/blob/be4d361435ef5727e72d0c52e2d457d7ae465c2d/edk2-rockchip/Platform/OrangePi/OrangePi5Plus/OrangePi5Plus.dsc
[rk-dsc]:
  https://github.com/edk2-porting/edk2-rk3588/blob/be4d361435ef5727e72d0c52e2d457d7ae465c2d/edk2-rockchip/Silicon/Rockchip/RK3588/RK3588Platform.dsc.inc
[rk-fdf]:
  https://github.com/edk2-porting/edk2-rk3588/blob/be4d361435ef5727e72d0c52e2d457d7ae465c2d/edk2-rockchip/Silicon/Rockchip/RK3588/RK3588.fdf
[fv-main]:
  https://github.com/edk2-porting/edk2-rk3588/blob/be4d361435ef5727e72d0c52e2d457d7ae465c2d/edk2-rockchip/Silicon/Rockchip/FvMainModules.fdf.inc
[rockchip-dsc]:
  https://github.com/edk2-porting/edk2-rk3588/blob/be4d361435ef5727e72d0c52e2d457d7ae465c2d/edk2-rockchip/Silicon/Rockchip/Rockchip.dsc.inc
[revyos]: https://mirror.iscas.ac.cn/revyos/extra/images/lpi4a/20260926/README.md
[ftpm-binding]:
  https://github.com/torvalds/linux/blob/v7.2/Documentation/devicetree/bindings/tpm/microsoft,ftpm.yaml
[spi-binding]:
  https://github.com/torvalds/linux/blob/v7.2/Documentation/devicetree/bindings/tpm/tcg,tpm_tis-spi.yaml
[i2c-binding]:
  https://github.com/torvalds/linux/blob/v7.2/Documentation/devicetree/bindings/tpm/tcg,tpm-tis-i2c.yaml
[tpm-kconfig]: https://github.com/torvalds/linux/blob/v7.2/drivers/char/tpm/Kconfig
[nixos-tpm]:
  https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/nixos/modules/system/boot/systemd/tpm2.nix
[cryptenroll]: https://www.freedesktop.org/software/systemd/man/latest/systemd-cryptenroll.html
[cryptenroll-source]: https://github.com/systemd/systemd/blob/v261.3/man/systemd-cryptenroll.xml
