{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "nix";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # it provides the command `nom` works just like `nix`
      # with more detailed log output
      nix-output-monitor
      nix-prefetch-github
      nix-tree
      nh
      devenv
      manix
      nurl
    ];

    nix = {
      # package = pkgs.nix;
      settings = {
        trusted-users = [
          "root"
          "${config.mine.user.name}"
        ];
        max-jobs = "auto";

        # The maximum number of parallel TCP connections used to fetch files from binary caches and by other downloads.
        # It defaults to 25. 0 means no limit.
        # http-connections = 128;

        # This option defines the maximum number of substitution jobs that Nix will try to run in
        # parallel. The default is 16. The minimum value one can choose is 1 and lower values will be
        # interpreted as 1.
        # max-substitution-jobs = 128;

        # The number of lines of the tail of the log to show if a build fails.
        log-lines = 25;

        # When free disk space in /nix/store drops below min-free during a build, Nix performs a
        # garbage-collection until max-free bytes are available or there is no more garbage.
        # A value of 0 (the default) disables this feature.
        # min-free = 128000000; # 128 MB
        # max-free = 1000000000; # 1 GB

        # Prevent garbage collection from altering nix-shells managed by nix-direnv
        # https://github.com/nix-community/nix-direnv#installation
        # keep-outputs = true;
        # keep-derivations = true;

        # Automatically detect files in the store that have identical contents, and replaces
        # them with hard links to a single copy. This saves disk space.
        auto-optimise-store = true;

        # Whether to warn about dirty Git/Mercurial trees.
        warn-dirty = false;
      };
    };
  };
}
