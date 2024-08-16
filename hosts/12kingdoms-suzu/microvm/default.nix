{
  nixpkgs,
  nixpkgs-2405,
  myvars,
  mylib,
  mynixcfg,
  mynixcfg-v055,
  daeuniverse,
  agenix,
  microvm,
  mysecrets,
  nuenv,
  ...
}: {
  imports = [
    # Include the microvm host module
    microvm.nixosModules.host
  ];

  microvm.vms = {
    suzi = {
      autostart = true;
      restartIfChanged = true;

      specialArgs = {
        inherit myvars mylib daeuniverse agenix mysecrets mynixcfg mynixcfg-v055 nuenv;
        nixpkgs = nixpkgs-2405;
      };

      config.imports = [./suzi];
    };

    mitsuha = {
      autostart = true;
      restartIfChanged = true;

      specialArgs = {
        inherit myvars mylib mynixcfg nuenv;
        nixpkgs = nixpkgs-2405;
      };

      config.imports = [./mitsuha];
    };
  };
}
