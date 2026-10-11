{
  # NOTE: the args not used in this file CAN NOT be removed!
  # because haumea pass argument lazily,
  # and these arguments are used in the functions like `mylib.nixosSystem`, `mylib.colmenaSystem`, etc.
  inputs,
  lib,
  mylib,
  myvars,
  system,
  genSpecialArgs,
  ...
}@args:
let
  # 大木 鈴, Ōki Suzu
  name = "suzu";
  tags = [
    name
    "aarch"
  ];
  ssh-user = "root";

  modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        "nixos/server/server-aarch64.nix"
        # host specific modules
        "hosts/12kingdoms-${name}"
      ])
      ++ [
      ];
  };

  inherit (inputs) nixpkgs;
  hostPkgs = import nixpkgs { inherit system; };
  hostSpecialArgs = genSpecialArgs system;
  hostSystemArgs =
    modules
    // args
    // {
      inherit nixpkgs;
      specialArgs = hostSpecialArgs;
    };
in
{
  nixosConfigurations.${name} = mylib.nixosSystem hostSystemArgs;

  colmenaMeta = {
    nodeSpecialArgs.${name} = hostSpecialArgs;
    nodeNixpkgs.${name} = hostPkgs;
  };
  colmena.${name} = mylib.colmenaSystem (hostSystemArgs // { inherit tags ssh-user; });
}
