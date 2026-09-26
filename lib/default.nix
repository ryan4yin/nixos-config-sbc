{ lib, mynixcfg, ... }:
let
  # Reuse nix-config's shared helpers instead of copying them into this repo.
  # `scanPaths` is path-agnostic; `nixosSystem`/`colmenaSystem`/`attrs` are generic.
  upstream = import "${mynixcfg}/lib" { inherit lib; };
in
upstream
// {
  # `relativeToRoot` is the one helper that is rooted at its own repo, so it must
  # resolve to *this* repo rather than to nix-config's checkout.
  relativeToRoot = lib.path.append ../.;
}
