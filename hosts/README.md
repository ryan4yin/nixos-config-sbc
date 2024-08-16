# Hosts

1. `12kingdoms`:
   1. `suzu`: Orange Pi 5, RK3588s(4xA76 + 4xA55), GPU(4Cores, Mail-G610), NPU(6Tops@int8), 8G RAM +
      256G SSD.
      - Network related services running via microvm.nix, such as router(transparent proxy - dae),
        tailscale subrouter, etc.
   1. `rakushun`: Orange Pi 5 Plus, RK3588(4xA76 + 4xA55), GPU(4Cores, Mail-G610), NPU(6Tops@int8),
      16G RAM + 2T SSD.
      - Not used now.
1. `rolling_girls`: My RISCV64 hosts.
   1. `nozomi`: Lichee Pi 4A, TH1520(4xC910@2.0G), 16GB RAM + 32G eMMC + 128G SD Card.
   2. `yukina`: Milk-V Mars, JH7110(4xU74@1.5 GHz), 4G RAM + No eMMC + 64G SD Card.

## How to add a new host

1. Under `hosts/`
   1. Create a new folder under `hosts/` with the name of the new host.
   2. Create & add the new host's `hardware-configuration.nix` to the new folder, and add the new
      host's `configuration.nix` to `hosts/<name>/default.nix`.
   3. If the new host need to use home-manager, add its custom config into `hosts/<name>/home.nix`.
1. Under `outputs/`
   1. Add a new nix file named `outputs/<system-architecture>/src/<name>.nix`.
   2. Copy the content from one of the existing similar host, and modify it to fit the new host.
      1. Usually, you only need to modify the `name` and `tags` fields.
   3. [Optional] Add a new unit test file under `outputs/<system-architecture>/tests/<name>.nix` to
      test the new host's nix file.
   4. [Optional] Add a new integration test file under
      `outputs/<system-architecture>/integration-tests/<name>.nix` to test whether the new host's
      nix config can be built and deployed correctly.
1. Under `vars/networking.nix`
   1. Add the new host's static IP address.
   1. Skip this step if the new host is not in the local network or is a mobile device.

## rolling girls

My All RISCV64 hosts.

![](/_img/nixos-riscv-cluster.webp)

## References

[Oshi no Ko 【推しの子】 - Wikipedia](https://en.wikipedia.org/wiki/Oshi_no_Ko):

![](/_img/idols-famaily.webp) ![](/_img/idols-ai.webp)

[The Rolling Girls【ローリング☆ガールズ】 - Wikipedia](https://en.wikipedia.org/wiki/The_Rolling_Girls):

![](/_img/rolling_girls.webp)

[List of Twelve Kingdoms characters](https://en.wikipedia.org/wiki/List_of_Twelve_Kingdoms_characters)

![](/_img/12kingdoms-1.webp) ![](/_img/12kingdoms-Youko-Rakushun.webp)

[List of Frieren characters](https://en.wikipedia.org/wiki/List_of_Frieren_characters)
