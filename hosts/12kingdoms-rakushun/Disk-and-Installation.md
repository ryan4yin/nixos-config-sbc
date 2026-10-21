# Rakushun - Disk and Installation

Disk layout:

```bash
[ryan@rakushun:~]$ lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sda           8:0    1 58.6G  0 disk
└─sda1        8:1    1  487M  0 part
mtdblock0    31:0    0   16M  0 disk
zram0       254:0    0    0B  0 disk
nvme0n1     259:0    0  1.8T  0 disk
├─nvme0n1p1 259:1    0  630M  0 part  /boot
└─nvme0n1p2 259:2    0  1.8T  0 part
  └─encrypted 253:0    0  1.8T  0 crypt /tmp
                                      /swap
                                      /snapshots
                                      /home/ryan/tmp
                                      /home/ryan/nix-config
                                      /home/ryan/go
                                      /home/ryan/codes
                                      /home/ryan/.ssh
                                      /home/ryan/.local/state
                                      /home/ryan/.npm
                                      /home/ryan/.local/share
                                      /home/ryan/.conda
                                      /etc/ssh
                                      /etc/nix/inputs
                                      /etc/secureboot
                                      /etc/agenix
                                      /etc/NetworkManager/system-connections
                                      /etc/machine-id
                                      /nix/store
                                      /var/log
                                      /var/lib
                                      /nix
                                      /persistent

[ryan@rakushun:~]$ df -Th
Filesystem          Type      Size  Used Avail Use% Mounted on
devtmpfs            devtmpfs  785M     0  785M   0% /dev
tmpfs               tmpfs     7.7G     0  7.7G   0% /dev/shm
tmpfs               tmpfs     3.9G  6.8M  3.9G   1% /run
tmpfs               tmpfs     7.7G  1.9M  7.7G   1% /run/wrappers
none                tmpfs     4.0G   48K  4.0G   1% /
/dev/mapper/crypted btrfs     1.9T   19G  1.8T   2% /persistent
/dev/mapper/crypted btrfs     1.9T   19G  1.8T   2% /nix
/dev/mapper/crypted btrfs     1.9T   19G  1.8T   2% /snapshots
/dev/mapper/crypted btrfs     1.9T   19G  1.8T   2% /swap
/dev/mapper/crypted btrfs     1.9T   19G  1.8T   2% /tmp
/dev/nvme0n1p1      vfat      629M   96M  534M  16% /boot
tmpfs               tmpfs     1.6G  4.0K  1.6G   1% /run/user/1000
```

CPU info:

```bash
[ryan@rakushun:~]$ lscpu
Architecture:           aarch64
  CPU op-mode(s):       32-bit, 64-bit
  Byte Order:           Little Endian
CPU(s):                 8
  On-line CPU(s) list:  0-7
Vendor ID:              ARM
  Model name:           Cortex-A55
    Model:              0
    Thread(s) per core: 1
    Core(s) per socket: 4
    Socket(s):          1
    Stepping:           r2p0
    CPU(s) scaling MHz: 67%
    CPU max MHz:        1800.0000
    CPU min MHz:        408.0000
    BogoMIPS:           48.00
    Flags:              fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm lrcpc dcpop asimddp
  Model name:           Cortex-A76
    Model:              0
    Thread(s) per core: 1
    Core(s) per socket: 2
    Socket(s):          2
    Stepping:           r4p0
    CPU(s) scaling MHz: 18%
    CPU max MHz:        2256.0000
    CPU min MHz:        408.0000
    BogoMIPS:           48.00
    Flags:              fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm lrcpc dcpop asimddp
Caches (sum of all):
  L1d:                  384 KiB (8 instances)
  L1i:                  384 KiB (8 instances)
  L2:                   2.5 MiB (8 instances)
  L3:                   3 MiB (1 instance)
```

## Fresh installation and recovery

Both hosts now use the shared
[Orange Pi 5 Plus installation procedure](../../docs/orangepi-installation.md). It covers official
live-media validation, verified physical disk selection, the host-specific raw USB unlock key,
recovery-passphrase enrollment, persistent identity and systemd-boot recovery. Record actual board
results in the [hardware validation record](../../docs/orangepi-hardware-validation.md). The
observations above describe an earlier installation; they do not verify the new mainline system.
