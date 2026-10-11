# Orange Pi hardware validation record

Use [the installation procedure](./orangepi-installation.md) to collect evidence. Empty fields and
unchecked rows mean **unverified**, not passed. Record metadata and observations only; never record
passphrases, raw USB unlock material, private keys or secret-bearing transcripts.

## Installation provenance

| Field                                      | rakushun   | suzu       |
| ------------------------------------------ | ---------- | ---------- |
| Board/revision and RAM                     | Unverified | Unverified |
| Repository commit and lock                 | Unverified | Unverified |
| Firmware artifact/version and checksum     | Unverified | Unverified |
| EDK2 DT mode and override settings         | Unverified | Unverified |
| Live ISO resolved filename/source          | Unverified | Unverified |
| Published and verified ISO checksum        | Unverified | Unverified |
| Live latest-kernel version and boot route  | Unverified | Unverified |
| Target physical disk identity confirmed    | Unverified | Unverified |
| Installed kernel and systemd-boot versions | Unverified | Unverified |
| Effective board DT identity and memory     | Unverified | Unverified |

## Physical acceptance

For each row, record the tested revision, date and concrete observation. Complete rakushun first,
then suzu. An installed-system boot must be checked independently of a successful live ISO boot.

| Check                                                              | rakushun       | suzu       |
| ------------------------------------------------------------------ | -------------- | ---------- |
| Official latest-kernel live ISO reaches usable console             | Unverified     | Unverified |
| Live USB, NVMe and network usable before formatting                | Unverified     | Unverified |
| Cold boot with raw USB unlock key                                  | Unverified     | Unverified |
| Recovery passphrase enrolled and tested locally                    | Unverified     | Unverified |
| Cold boot without USB key reaches passphrase prompt and unlocks    | Unverified     | Unverified |
| NVMe and all required filesystem mounts                            | Unverified     | Unverified |
| Both Ethernet ports: identity, link, speed and traffic             | Unverified     | Unverified |
| Fan, temperature and throttling under normal workload              | Unverified     | Unverified |
| Clean reboot and stable persistent machine/SSH identity            | Unverified     | Unverified |
| Boot menu selection of a prior mainline generation after an update | Unverified     | Unverified |
| Verified live USB can reach the existing system for repair         | Unverified     | Unverified |
| Mitsuha starts and has working networking                          | Not applicable | Unverified |

## Update and observation log

Keep one row per host/update; include a real kernel version change rather than inferring it from a
new nixpkgs revision. Stop and resolve blocking failures before treating a host as
hardware-verified.

| Host             | Date | Repository/lock revision | Kernel before/after | Boot and recovery observation | Open blocking issues |
| ---------------- | ---- | ------------------------ | ------------------- | ----------------------------- | -------------------- |
| Not yet observed | —    | —                        | —                   | —                             | Unverified           |

## Gate for moving aarch64 back to nix-config

Both hosts must complete physical acceptance, each run for at least 14 days, and pass two ordinary
nixpkgs updates including at least one kernel version upgrade. There must be no unresolved blocking
boot, unlock, storage, networking or VM issue. Record the verified firmware/DT settings and recovery
media alongside the host configurations when moving them. Continue using shared nix-config patterns
and carry only the small board module and host-specific wiring. RISC-V remains here until its own
kernel/build/boot migration is validated.
