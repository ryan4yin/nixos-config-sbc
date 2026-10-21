{ pkgs, ... }:
{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "rootwait"
    "console=ttyS2,1500000"
    "console=tty1"
  ];

  boot.initrd.systemd.enable = true;

  boot.loader.grub.enable = false;
  boot.loader.systemd-boot = {
    enable = true;
    # Bound distinct kernel/initrd copies on the 630 MiB ESP.
    configurationLimit = 5;
    # Preserve EDK2's Mainline DT and runtime fixups instead of loading the packaged DTB.
    installDeviceTree = false;
  };

  # Independent DT-probed PHYs must be available before USB key and root discovery.
  boot.initrd.availableKernelModules = [
    "phy-rockchip-naneng-combphy"
    "phy-rockchip-usbdp"
    "dwc3"
    "dwc3-of-simple"
    "xhci_plat_hcd"
    "ehci_platform"
    "ohci_platform"
  ];

  # Keep the kernel DT artifact available for inspection; the bootloader uses firmware DT.
  hardware.deviceTree.name = "rockchip/rk3588-orangepi-5-plus.dtb";
  hardware.enableRedistributableFirmware = true;
}
