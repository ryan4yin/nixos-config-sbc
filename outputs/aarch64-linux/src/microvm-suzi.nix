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
} @ args: let
  name = "suzi";
  tags = [name "aarch"];
  ssh-user = "root";

  modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        # host specific modules
        "hosts/microvm-${name}"
      ])
      ++ [
        # this runs as a MicroVM
        inputs.microvm.nixosModules.microvm
        {
          networking.hostName = name;
        }
      ];
  };

  nixpkgs = inputs.nixpkgs-microvm;
  baseSpecialArgs = genSpecialArgs system;
  specialArgs =
    baseSpecialArgs
    // {
      inherit nixpkgs;
    };
  systemArgs =
    modules
    // args
    // {
      inherit nixpkgs;
      specialArgs = specialArgs;
    };
in {
  nixosConfigurations.${name} = mylib.nixosSystem systemArgs;
}
