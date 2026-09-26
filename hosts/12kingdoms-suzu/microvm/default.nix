{
  pkgs,
  nixpkgs-microvm,
  myvars,
  mylib,
  mynixcfg,
  microvm,
  nuenv,
  ...
}: {
  imports = [
    # Include the microvm host module
    microvm.nixosModules.host
  ];

  microvm.vms = {
    mitsuha = {
      autostart = true;
      restartIfChanged = true;

      # The package set to use for the microvm. This also determines the microvm's architecture.
      # Defaults to the host system's package set if not given.
      pkgs = import nixpkgs-microvm {system = pkgs.stdenv.system;};

      # A set of special arguments to be passed to the MicroVM's NixOS modules.
      specialArgs = {
        inherit myvars mylib mynixcfg nuenv;
        nixpkgs = nixpkgs-microvm;
      };

      config.imports = [../../microvm-mitsuha];
    };
  };
}
