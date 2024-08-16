# ================= NixOS related =========================

export def nixos-switch [
    name: string
    mode: string
] {
    if "debug" == $mode {
        # show details via nix-output-monitor
        nom build $".#nixosConfigurations.($name).config.system.build.toplevel" --show-trace --verbose
        nixos-rebuild switch --use-remote-sudo --flake $".#($name)" --show-trace --verbose
    } else {
        nixos-rebuild switch --use-remote-sudo --flake $".#($name)"
    }
}

