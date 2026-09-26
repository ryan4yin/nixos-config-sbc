{
  description = "Ryan Yin's nix configuration for aarch64 and riscv64 SBCs";

  ##################################################################################################################
  #
  # Want to know Nix in details? Looking for a beginner-friendly tutorial?
  # Check out https://github.com/ryan4yin/nixos-and-flakes-book !
  #
  ##################################################################################################################

  outputs = inputs: import ./outputs inputs;

  # the nixConfig here only affects the flake itself, not the system configuration!
  # for more information, see:
  #     https://nixos-and-flakes.thiscute.world/nix-store/add-binary-cache-servers
  nixConfig = {
    # substituers will be appended to the default substituters when fetching packages
    extra-substituters = [
      "https://cache.garnix.io"
    ];
    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };

  # This is the standard format for flake.nix. `inputs` are the dependencies of the flake,
  # Each item in `inputs` will be passed as a parameter to the `outputs` function after being pulled and built.
  inputs = {
    # There are many ways to reference flake inputs. The most widely used is github:owner/name/reference,
    # which represents the GitHub repository URL + branch/commit-id/tag.

    # Used only as colmena's default nixpkgs, will be overwritten in each host by colmenaMeta.nodeNixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    # Used as microvm's nixpkgs
    nixpkgs-microvm.url = "github:nixos/nixpkgs/nixos-unstable";

    # nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # home-manager, used for managing user configuration
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      # url = "github:nix-community/home-manager/release-24.11";

      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs dependencies.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    preservation.url = "github:nix-community/preservation";

    disko = {
      url = "github:nix-community/disko/v1.13.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # add git hooks to format nix code before commit
    # NOTE: keep this pinned to a revision compatible with the nixpkgs line above;
    # newer git-hooks.nix expects packages (e.g. `air-formatter`) absent from 24.11.
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix/9364dc02281ce2d37a1f55b6e51f7c0f65a75f17";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nuenv.url = "github:DeterminateSystems/nuenv";

    haumea = {
      url = "github:nix-community/haumea/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ########################  My own repositories  #########################################

    # This repo consumes `nix-config`'s `vars/`, so pin it to a revision whose vars API
    # matches (e.g. `defaultGateway`, `sshAuthorizedKeys`). Tracking `main` breaks eval as
    # soon as those names change (they were renamed upstream around 2025-05).
    mynixcfg.url = "github:ryan4yin/nix-config/417d7ad2d78fd10799bafe687c0d4fe713c92fb5";

    # riscv64 SBCs
    nixos-licheepi4a.url = "github:ryan4yin/nixos-licheepi4a";
    # nixos-jh7110.url = "github:ryan4yin/nixos-jh7110";

    # aarch64 SBCs
    nixos-rk3588.url = "github:ryan4yin/nixos-rk3588";
  };
}
