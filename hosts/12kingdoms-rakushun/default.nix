{
  mylib,
  disko,
  myvars,
  ...
}:
#############################################################
#
#  Rakushun - Orange Pi 5 Plus, RK3588 + 16GB RAM
#
#############################################################
let
  hostName = "rakushun"; # Define your hostname.
in
{
  imports = (mylib.scanPaths ./.) ++ [
    (mylib.relativeToRoot "nixos/boards/orangepi5plus.nix")
    disko.nixosModules.default
  ];

  networking = {
    inherit hostName;
    inherit (myvars.networking) nameservers;
    # upstream renamed `defaultGateway` to `proxyGateway`; keep the NixOS option name
    defaultGateway = myvars.networking.proxyGateway;
    interfaces.${myvars.networking.hostsAddr.${hostName}.iface} = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = myvars.networking.hostsAddr.${hostName}.ipv4;
          prefixLength = 24;
        }
      ];
    };
    networkmanager.enable = false;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
