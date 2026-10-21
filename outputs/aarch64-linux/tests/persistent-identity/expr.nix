{ lib, outputs }:
lib.genAttrs [ "suzu" "rakushun" ] (
  name:
  let
    config = outputs.nixosConfigurations.${name}.config;
  in
  config.fileSystems."/persistent".neededForBoot
  && lib.elem "systemd-machine-id-commit.service" config.systemd.suppressedSystemUnits
  && lib.any (
    mount:
    mount.where == "/sysroot/etc/machine-id"
    && mount.what == "/sysroot/persistent/etc/machine-id"
    && lib.elem "initrd-preservation.target" mount.before
  ) config.boot.initrd.systemd.mounts
)
