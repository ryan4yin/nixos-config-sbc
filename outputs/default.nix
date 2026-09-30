{
  self,
  mynixcfg,
  nixpkgs,
  pre-commit-hooks,
  ...
}@inputs:
let
  inherit (inputs.nixpkgs) lib;
  mylib = import ../lib { inherit lib mynixcfg; };
  myvars = import "${mynixcfg}/vars" { inherit lib; };

  # Add my custom lib, vars, nixpkgs instance, and all the inputs to specialArgs,
  # so that I can use them in all my nixos/home-manager/darwin modules.
  genSpecialArgs =
    system:
    inputs
    // {
      inherit mylib myvars;
    };

  # This is the args for all the haumea modules in this folder.
  args = {
    inherit
      inputs
      lib
      mylib
      myvars
      genSpecialArgs
      ;
  };

  # modules for each supported system
  nixosSystems = {
    aarch64-linux = import ./aarch64-linux (args // { system = "aarch64-linux"; });
    riscv64-linux = import ./riscv64-linux (args // { system = "riscv64-linux"; });
  };
  darwinSystems = { };
  allSystems = nixosSystems // darwinSystems;
  allSystemNames = builtins.attrNames allSystems;
  nixosSystemValues = builtins.attrValues nixosSystems;
  darwinSystemValues = builtins.attrValues darwinSystems;
  allSystemValues = nixosSystemValues ++ darwinSystemValues;

  # Helper function to generate a set of attributes for each system
  forAllSystems = func: (nixpkgs.lib.genAttrs allSystemNames func);

  # Systems that only need the checks / dev-shell / formatter outputs and have
  # no nixosConfiguration of their own (e.g. the x86_64 dev machine and CI
  # runners). Without this, `nix develop` / `nix fmt` fail on x86_64.
  devSystemNames = allSystemNames ++ [ "x86_64-linux" ];
  forAllDevSystems = func: (nixpkgs.lib.genAttrs devSystemNames func);
in
{
  # Add attribute sets into outputs, for debugging
  debugAttrs = {
    inherit
      nixosSystems
      darwinSystems
      allSystems
      allSystemNames
      ;
  };

  # NixOS Hosts
  nixosConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.nixosConfigurations or { }) nixosSystemValues
  );

  # Colmena - remote deployment via SSH
  colmena = {
    meta =
      (
        let
          system = "x86_64-linux";
        in
        {
          # colmena's default nixpkgs & specialArgs
          nixpkgs = import nixpkgs { inherit system; };
          specialArgs = genSpecialArgs system;
        }
      )
      // {
        # per-node nixpkgs & specialArgs
        nodeNixpkgs = lib.attrsets.mergeAttrsList (
          map (it: it.colmenaMeta.nodeNixpkgs or { }) nixosSystemValues
        );
        nodeSpecialArgs = lib.attrsets.mergeAttrsList (
          map (it: it.colmenaMeta.nodeSpecialArgs or { }) nixosSystemValues
        );
      };
  }
  // lib.attrsets.mergeAttrsList (map (it: it.colmena or { }) nixosSystemValues);

  # macOS Hosts
  darwinConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.darwinConfigurations or { }) darwinSystemValues
  );

  # Packages
  packages = forAllSystems (system: allSystems.${system}.packages or { });

  # Eval Tests for all NixOS & darwin systems.
  evalTests = lib.lists.all (it: it.evalTests == { }) allSystemValues;

  checks = forAllDevSystems (
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      # RFC 166 nixfmt, not available in the pinned 24.11 nixpkgs.
      nixfmt = (import inputs.nixpkgs-unstable { inherit system; }).nixfmt;
    in
    {
      # eval-tests per system. `nix flake check` requires every check to be a
      # derivation, so wrap the boolean result in one instead of returning a bool.
      eval-tests =
        let
          # x86_64-linux has no nixosConfigurations, so its eval tests are vacuously empty.
          results = allSystems.${system}.evalTests or { };
        in
        pkgs.runCommand "eval-tests" { } (
          if results == { } then
            "touch $out"
          else
            "echo 'eval tests failed: evalTests is not empty' >&2; exit 1"
        );

      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = mylib.relativeToRoot ".";
        hooks = {
          # `hooks.nixfmt` resolves to the classic formatter on the pinned 24.11
          # nixpkgs, so use the explicit RFC-style hook with the unstable package.
          nixfmt-rfc-style = {
            enable = true; # formatter (RFC 166 style)
            package = nixfmt;
            settings.width = 100;
          };
          # Source code spell checker
          typos = {
            enable = true;
            settings = {
              write = true; # Automatically fix typos
              configPath = ".typos.toml"; # relative to the flake root
            };
          };
          prettier = {
            enable = true;
            settings = {
              write = true; # Automatically format files
              configPath = ".prettierrc.yaml"; # relative to the flake root
            };
          };
          # deadnix.enable = true; # detect unused variable bindings in `*.nix`
          # statix.enable = true; # lints and suggestions for Nix code(auto suggestions)
        };
      };
    }
  );

  # Development Shells
  devShells = forAllDevSystems (
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      # RFC 166 nixfmt, not available in the pinned 24.11 nixpkgs.
      nixfmt = (import inputs.nixpkgs-unstable { inherit system; }).nixfmt;
    in
    {
      default = pkgs.mkShell {
        packages = with pkgs; [
          # fix https://discourse.nixos.org/t/non-interactive-bash-errors-from-flake-nix-mkshell/33310
          bashInteractive
          # fix `cc` replaced by clang, which causes nvim-treesitter compilation error
          gcc
          # Nix-related
          nixfmt
          deadnix
          statix
          # spell checker
          typos
          # code formatter
          nodePackages.prettier
        ];
        name = "dots";
        shellHook = ''
          ${self.checks.${system}.pre-commit-check.shellHook}
        '';
      };
    }
  );

  # Format the nix code in this flake
  formatter = forAllDevSystems (
    # nixfmt (RFC 166 style) comes from the unstable tooling input.
    system: (import inputs.nixpkgs-unstable { inherit system; }).nixfmt
  );
}
