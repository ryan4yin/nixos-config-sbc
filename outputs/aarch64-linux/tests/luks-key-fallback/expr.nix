{ lib, outputs }:
lib.genAttrs [ "suzu" "rakushun" ] (
  name:
  let
    initrd = outputs.nixosConfigurations.${name}.config.boot.initrd;
    device = initrd.luks.devices.encrypted;
  in
  # Without a timeout, systemd requires the missing key device before it can ask for a password.
  !initrd.systemd.enable
  || device.keyFile == null
  || !(lib.hasPrefix "/dev/" device.keyFile)
  || (device.keyFileTimeout != null && device.keyFileTimeout > 0)
)
