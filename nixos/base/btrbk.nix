{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.btrbk;
in
{
  # ==================================================================
  #
  # btrbk - scheduled LOCAL btrfs snapshots.
  #   https://github.com/digint/btrbk
  #
  # Snapshots are created in `snapshotDir` (relative to the btrfs top-level
  # subvolume mounted at `volume`) and pruned by `snapshot_preserve`. With the
  # defaults they land in the @snapshots subvolume (mounted at /snapshots):
  #
  #   /btr_pool/@snapshots/@persistent.<timestamp>
  #
  # These are same-filesystem snapshots: they protect against accidental
  # deletion and bad edits, NOT against disk loss.
  #
  # The host MUST mount the btrfs top-level subvolume (subvolid=5) at `volume`;
  # this is enforced by an assertion so a missing mount fails evaluation instead
  # of failing silently.
  #
  # Restore a snapshot (offline; stop writers first):
  #   1. btrfs subvolume delete /btr_pool/@persistent
  #   2. btrfs subvolume snapshot /btr_pool/@snapshots/@persistent.<timestamp> \
  #        /btr_pool/@persistent
  #   3. reboot, or remount /persistent, to pick up the restored subvolume.
  #
  # ==================================================================
  options.modules.btrbk = {
    # Enabled by default to keep the previous always-on behaviour for the
    # aarch64 servers that import this module.
    enable = (lib.mkEnableOption "scheduled btrfs snapshots via btrbk") // {
      default = true;
    };

    volume = lib.mkOption {
      type = lib.types.str;
      default = "/btr_pool";
      description = "Mount point of the btrfs top-level subvolume (subvolid=5).";
    };

    subvolume = lib.mkOption {
      type = lib.types.str;
      default = "@persistent";
      description = "Source subvolume to snapshot, relative to `modules.btrbk.volume`.";
    };

    snapshotDir = lib.mkOption {
      type = lib.types.str;
      default = "@snapshots";
      description = "Directory the snapshots are created in, relative to `modules.btrbk.volume`.";
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "Tue,Thu,Sat *-*-* 3:45:20";
      description = "systemd calendar expression for the snapshot timer.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.hasAttr cfg.volume config.fileSystems;
        message = "modules.btrbk: no filesystem is mounted at `${cfg.volume}`; mount the btrfs top-level subvolume (subvolid=5) there so btrbk can snapshot `${cfg.volume}/${cfg.subvolume}`.";
      }
    ];

    services.btrbk.instances.btrbk = {
      inherit (cfg) onCalendar;
      settings = {
        # keep daily snapshots for 9 days, and always keep the last 2 days.
        snapshot_preserve = "9d";
        snapshot_preserve_min = "2d";

        volume.${cfg.volume} = {
          snapshot_dir = cfg.snapshotDir;
          subvolume.${cfg.subvolume} = {
            snapshot_create = "always";
          };
        };
      };
    };
  };
}
