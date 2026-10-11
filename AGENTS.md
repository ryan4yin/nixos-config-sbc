# AGENTS.md

Nix flake for Ryan's aarch64 (RK3588) and riscv64 SBC hosts, deployed with colmena (remote SSH) and
microvm.nix (VMs on `suzu`). The Orange Pi 5 Plus hosts use standard nixpkgs kernels; this repo
keeps its own input lock and hardware validation cycle separate from `ryan4yin/nix-config`.

## Commands

`just` drives everything; it uses nushell (`set shell := ["nu", "-c"]`), so both `just` and `nu`
must be on PATH: `nix shell nixpkgs#just nixpkgs#nushell`.

- `just test` - strict full-tree eval checks. This is the CI gate. Run it after edits.
- `just test-aarch64` - focused aarch64 eval checks for the primary validation target.
- `just eval-host <host>` / `just build-host <host>` - force the full system derivation / build its
  closure without activation. Use these for `suzu` and `rakushun` after kernel or input changes.
- `just fmt` - format `.nix` files with nixfmt (RFC 166 style, width 100). `nix fmt` also works (the
  `formatter` output exists for `x86_64-linux` too), but pass files explicitly.
- `nix develop` - dev shell; its shellHook installs pre-commit hooks (nixfmt, typos --write,
  prettier --write).
- `just col <tag> [mode]` / `just riscv|nozomi|yukina` - deploy via `colmena apply --on '@<tag>'`
  (`mode` defaults to `switch`; use `boot` for network-stack changes).
- `just vm <hostname>` - build & install a microvm on `suzu`.
- `just suzu-local [mode]` / `just rakushun-local [mode]` - `nixos-rebuild switch` locally
  (`mode=debug` adds nom/verbose).
- `just up` / `just upp <input>` - update all / one flake input and commit the lock update.
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
- `lib/` re-exports nix-config's shared helpers (`nixosSystem`, `colmenaSystem`, `attrs`,
  `scanPaths`) from the locked `mynixcfg` input instead of copying them; only `relativeToRoot` is
  local, because upstream roots it at the nix-config checkout while this repo needs its own root.
- OPi hosts use root nixpkgs in both NixOS and Colmena, with `nixos/boards/orangepi5plus.nix`.
  MicroVMs use `nixpkgs-microvm`. RISC-V hosts retain the external `nixos-licheepi4a` package set.

## Adding / changing a host

- `hosts/README.md` has the step-by-step. Its `vars/networking.nix` and `vars/username` steps live
  in the **external** `mynixcfg` input, not this repo.
- Before OPi installation, kernel, loader or firmware changes, read `docs/orangepi-installation.md`:
  it covers live-media validation, raw-key/passphrase enrollment, firmware DT handoff and recovery.
  For support-state claims or moving hosts back to nix-config, read
  `docs/orangepi-hardware-validation.md`.
- `outputs/<system>/src/*.nix` header comment is real: do **not** remove seemingly unused args
  (haumea passes them lazily into `mylib.nixosSystem`/`mylib.colmenaSystem`).

## Gotchas

- Preserve explicit release/tag/revision references when updating inputs. `myvars` and `mylib` come
  from the revision-pinned external `mynixcfg` input; bumping that revision can change its API. OPi
  networking uses `hostsAddr.<host>.iface` / `.ipv4`, while gateway and SSH keys use `proxyGateway`
  and `mainSshAuthorizedKeys`. Check these consumers together when updating the input.
- `nozomi` / `yukina` receive minimal vars-API compatibility fixes and participate in eval CI, but
  their kernel, system builds and boot remain unverified. A later RISC-V migration must verify its
  native/cross kernel package selection and actual hardware.
- Per-architecture test results must equal `{}`. Root `evalTests` forces both OPi Colmena system
  derivations and returns the architecture-test boolean aggregation. `just test` asserts it is true;
  `just test-aarch64` asserts the aarch64 empty-failure result. Test directories are
  `outputs/<system>/tests/<name>/{expr.nix,expected.nix}`.
- Formatters differ: nixfmt (width 100) for `.nix`, prettier (`.prettierrc.yaml`) for everything
  else, typos (`.typos.toml`) for spelling. Pre-commit hooks auto-fix on commit.
- Successful eval/build does not establish a hardware boot. Validate encrypted-root unlock, firmware
  DT mode, storage/network and recovery on an OPi before activating an upgrade.
