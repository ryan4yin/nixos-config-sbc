# just is a command runner, Justfile is very similar to Makefile, but simpler.

# Use nushell for shell commands
# To usage this justfile, you need to enter a shell with just & nushell installed:
# 
#   nix shell nixpkgs#just nixpkgs#nushell
set shell := ["nu", "-c"]

utils_nu := absolute_path("utils.nu")

############################################################################
#
#  Common commands(suitable for all machines)
#
############################################################################

# List all the just commands
default:
    @just --list

# Run eval tests
[group('nix')]
test:
  nix eval .#evalTests --show-trace --print-build-logs --verbose

# Evaluate a NixOS host configuration without building it.
[linux]
[group('nix')]
eval-host host:
  nix eval .#nixosConfigurations.{{host}}.config.system.build.toplevel.drvPath --raw --show-trace

# Build a NixOS host system closure without changing the current system.
[linux]
[group('nix')]
build-host host:
  nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel --no-link --print-build-logs

# Build a MicroVM runner locally. Deploy it with `just vm` so the closure is copied remotely.
[linux]
[group('nix')]
build-microvm guest:
  nix build .#nixosConfigurations.{{guest}}.config.microvm.declaredRunner --no-link --print-build-logs

# Update all the flake inputs
[group('nix')]
up:
  nix flake update --commit-lock-file

# Update specific input
# Usage: just upp nixpkgs
[group('nix')]
upp input:
  nix flake update {{input}} --commit-lock-file

# List all generations of the system profile
[group('nix')]
history:
  nix profile history --profile /nix/var/nix/profiles/system

# Open a nix shell with the flake
[group('nix')]
repl:
  nix repl -f flake:nixpkgs

# remove all generations older than 7 days
# on darwin, you may need to switch to root user to run this command
[group('nix')]
clean:
  sudo nix profile wipe-history --profile /nix/var/nix/profiles/system  --older-than 7d

# Garbage collect all unused nix store entries
[group('nix')]
gc:
  # garbage collect all unused nix store entries(system-wide)
  sudo nix-collect-garbage --delete-older-than 7d
  # garbage collect all unused nix store entries(for the user - home-manager)
  # https://github.com/LnL7/nix-darwin/issues/237
  nix-collect-garbage --delete-older-than 7d

# Enter a shell session which has all the necessary tools for this flake
[linux]
[group('nix')]
shell:
  nix shell nixpkgs#git nixpkgs#neovim nixpkgs#colmena

# Enter a shell session which has all the necessary tools for this flake
[macos]
[group('nix')]
shell:
  nix shell nixpkgs#git nixpkgs#neovim

[group('nix')]
fmt:
  # format the nix files in this repo
  nix fmt .

# Show all the auto gc roots in the nix store
[group('nix')]
gcroot:
  ls -al /nix/var/nix/gcroots/auto/

# Remote deployment via colmena
[linux]
[group('homelab')]
col tag mode="switch":
  colmena apply {{mode}} --on '@{{tag}}' --verbose --show-trace

[linux]
[group('homelab')]
vm hostname:
  # build the vm on the host
  nix run .#nixosConfigurations.{{hostname}}.config.microvm.deploy.installOnHost root@suzu

  # update the vm via restart it on the host
  # ssh root@suzu systemctl restart microvm@{{hostname}}

  # or switch to the new version in the vm
  nix run .#nixosConfigurations.{{hostname}}.config.microvm.deploy.sshSwitch root@{{hostname}} switch

############################################################################
#
#  RISC-V related commands
#
############################################################################

[linux]
[group('homelab')]
riscv:
  colmena apply --on '@riscv' --verbose --show-trace

[linux]
[group('homelab')]
nozomi:
  colmena apply --on '@nozomi' --verbose --show-trace

[linux]
[group('homelab')]
yukina:
  colmena apply --on '@yukina' --verbose --show-trace

############################################################################
#
# Aarch64 related commands
#
############################################################################

[linux]
[group('homelab')]
rakushun:
  colmena apply --on '@rakushun' --build-on-target --verbose --show-trace

[linux]
[group('homelab')]
rakushun-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch rakushun {{mode}}

[linux]
[group('homelab')]
suzu-set-proxy:
  ip route del default via 192.168.5.1
  ip route add default via 192.168.5.178

[linux]
[group('homelab')]
suzu-unset-proxy:
  ip route del default via 192.168.5.178
  ip route add default via 192.168.5.1

[linux]
[group('homelab')]
suzu-local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *; 
  nixos-switch suzu {{mode}}


