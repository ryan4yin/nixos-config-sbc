{ pkgs, ... }:
{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "rootwait"
    "console=ttyS2,1500000"
    "console=tty1"
  ];

  boot.initrd.systemd.enable = true;

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

  # EFI GRUB uses the firmware's Mainline DT mode; this names the kernel DT artifact.
  hardware.deviceTree.name = "rockchip/rk3588-orangepi-5-plus.dtb";
  hardware.enableRedistributableFirmware = true;
}
