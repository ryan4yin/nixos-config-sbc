{ lib, outputs }:
lib.genAttrs [ "suzu" "rakushun" ] (
  name:
  let
    host = outputs.nixosConfigurations.${name};
    config = host.config;
    loader = config.boot.loader;
  in
  loader.systemd-boot.enable
  && !loader.grub.enable
  && !loader.systemd-boot.installDeviceTree
  && loader.systemd-boot.configurationLimit > 1
  && loader.timeout > 0
  && config.boot.kernelPackages.kernel.drvPath == host.pkgs.linuxPackages_latest.kernel.drvPath
)
