# Library

This repo does not keep its own copies of the shared helpers. `default.nix` imports them from the
pinned `nix-config` flake input (`mynixcfg`):

1. `attrs.nix`: functions to manipulate attribute sets.
1. `macosSystem.nix`: a function to generate config for
   macOS([nix-darwin](https://github.com/LnL7/nix-darwin)).
1. `nixosSystem.nix`: a function to generate config for NixOS.
1. `colmenaSystem.nix`: a function that generates config for remote deployment using
   [colmena](https://github.com/zhaofengli/colmena).
1. `genMicrovmGuestModule.nix` / `genVmHostModule.nix` and the k3s helpers: unused here, but
   exported from the same upstream library.

Only `relativeToRoot` is overridden locally, because upstream roots it at the `nix-config` checkout
while this repo needs it to point at its own root. `scanPaths` is path-agnostic and used as-is.
