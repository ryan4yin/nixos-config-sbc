# AGENTS.md

Nix flake for Ryan's aarch64 (RK3588) and riscv64 SBC hosts, deployed with colmena (remote SSH) and
microvm.nix (VMs on `suzu`). This repo is deliberately separate from `ryan4yin/nix-config` so SBC
nixpkgs can be pinned/bumped without breaking kernels/uboot.

## Commands

`just` drives everything; it uses nushell (`set shell := ["nu", "-c"]`), so both `just` and `nu`
must be on PATH: `nix shell nixpkgs#just nixpkgs#nushell`.

- `just test` - run eval tests (`nix eval .#evalTests`). This is the CI check. Run it after edits.
- `nix fmt` - format `.nix` files with alejandra.
- `nix develop` - dev shell; its shellHook installs pre-commit hooks (alejandra, typos --write,
  prettier --write).
- `just col <tag>` / `just riscv|nozomi|yukina` - deploy via `colmena apply --on '@<tag>'`.
- `just vm <hostname>` - build & install a microvm on `suzu`.
- `just suzu-local [mode]` / `just rakushun-local [mode]` - `nixos-rebuild switch` locally
  (`mode=debug` adds nom/verbose).
- `just up` / `just upp <input>` - update all / one flake input.
- `just shell` - nix shell with git/neovim/colmena (not the dev shell).

## Architecture

- `flake.nix` -> `outputs/default.nix` -> per-arch `outputs/<system>/default.nix` (haumea loads
  `outputs/<system>/src/*.nix`, merged into `nixosConfigurations`, `colmena`, `colmenaMeta`,
  `packages`).
- Systems: `aarch64-linux`, `riscv64-linux` only.
- A host needs **two** files: `hosts/<name>/` (NixOS modules, imported by path via
  `mylib.relativeToRoot`) and `outputs/<system>/src/<name>.nix` (flake-output wiring). MicroVMs use
  `hosts/microvm-<name>/` + `outputs/<system>/src/microvm-<name>.nix`.
- `nixos/base/` = shared modules; `nixos/server/server-{aarch64,riscv64}.nix` = per-arch base.
- `lib/` = custom helpers (`nixosSystem`, `colmenaSystem`, `scanPaths`, `relativeToRoot`).
- Kernel/firmware come from external flakes `nixos-rk3588` / `nixos-licheepi4a`; each host pins its
  own nixpkgs (`nixos-rk3588.inputs.nixpkgs`, or `nixpkgs-microvm` for VMs).

## Adding / changing a host

- `hosts/README.md` has the step-by-step. Note its `vars/networking.nix` and `vars/username` steps
  live in the **external** `mynixcfg` input, not this repo.
- `outputs/<system>/src/*.nix` header comment is real: do **not** remove seemingly unused args
  (haumea passes them lazily into `mylib.nixosSystem`/`mylib.colmenaSystem`).

## Gotchas

- `myvars` (username, host IPs) comes from the `mynixcfg` input; `mysecrets` is a **private** SSH
  flake input (`git+ssh://git@github.com/ryan4yin/nix-secrets.git`). Eval/build needs access to
  both.
- Do **not** run `nix flake check` or eval `.#checks` - it stack-overflows (see CI comment). Use
  `just test`.
- `evalTests` must equal `{}` (all true). Test dirs are
  `outputs/<system>/tests/<name>/{expr.nix,expected.nix}`.
- Formatters differ: alejandra for `.nix`, prettier (`.prettierrc.yaml`) for everything else, typos
  (`.typos.toml`) for spelling. Pre-commit hooks auto-fix on commit.
- Keep this repo on its pinned nixpkgs line; bumping nixpkgs here can break SBC kernel/uboot —
  verify on hardware, not just eval.
