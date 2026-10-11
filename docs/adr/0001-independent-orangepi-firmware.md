# Keep Orange Pi firmware independent of system updates

Orange Pi 5 Plus uses stock mainline Linux from nixpkgs unstable with independently maintained EDK2
firmware and systemd-boot. `installDeviceTree = false` keeps the firmware's Mainline DT and runtime
fixups, avoiding a new OS-DT handoff requirement; firmware changes are reserved for demonstrated
problems or required hardware support. Provisioning is a fresh installation, with manual recovery to
previous mainline generations and a verified live USB rather than compatibility with removed vendor
systems.
