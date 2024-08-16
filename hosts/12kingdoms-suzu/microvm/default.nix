{
  nixpkgs,
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

      specialArgs = {inherit myvars mylib daeuniverse agenix mysecrets mynixcfg mynixcfg-v055 nixpkgs nuenv;};

      config.imports = [./suzi];
    };

    mitsuha = {
      autostart = true;
      restartIfChanged = true;

      specialArgs = {inherit myvars mylib mynixcfg nixpkgs nuenv;};

      config.imports = [./mitsuha];
    };
  };
}
