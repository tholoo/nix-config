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
  name = "frdict";

  projectDir = "${config.home.homeDirectory}/projects/french-learning/frdict";
  dbPath = "${config.home.homeDirectory}/.cache/frdict/french.sqlite";

  # uv overlays Python deps from PyPI on top of nix's python3. Used here so
  # we can pull piper-tts (not packaged as python3Packages.* in this nixpkgs
  # revision) without rebuilding nixpkgs. Caches at ~/.cache/uv; first launch
  # downloads ~150MB. piper-tts gives the in-process Piper API — model loads
  # once at server start, ~50ms per /speak instead of ~1.5s with the CLI.
  pythonDeps = [
    "piper-tts"
    "fastapi"
    "uvicorn"
    "httpx"
    "pydantic"
  ];
  withFlags = lib.concatMapStringsSep " " (p: "--with ${p}") pythonDeps;
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "study"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      piper-tts # CLI fallback if the uv-overlaid Python module fails to load
    ];

    programs.uv.enable = true;

    systemd.user.services.frdict = {
      Unit = {
        Description = "Local French dictionary HTTP service";
        # Skip the unit silently if the SQLite DB hasn't been built yet —
        # user runs `python build.py` to populate it.
        ConditionPathExists = dbPath;
        # uv may need network on first start to fetch wheels into its cache.
        After = [ "default.target" "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        ExecStart = "${pkgs.uv}/bin/uv run --no-project --python ${pkgs.python3}/bin/python ${withFlags} ${projectDir}/server.py";
        Restart = "on-failure";
        # First launch may spend ~30s downloading wheels — give it room.
        RestartSec = "10s";
        Environment = [
          "PYTHONUNBUFFERED=1"
          "FRDICT_DB=${dbPath}"
          "HOME=${config.home.homeDirectory}"
          # uv needs to reach PyPI on first launch to fetch wheels. systemd
          # user services start with a clean env, so proxy vars from the
          # interactive shell don't carry over — set them explicitly. After
          # the first successful start, ~/.cache/uv is populated and the
          # proxy is no longer hit on restarts.
          "HTTPS_PROXY=http://127.0.0.1:10808"
          "HTTP_PROXY=http://127.0.0.1:10808"
          "ALL_PROXY=http://127.0.0.1:10808"
          # Manylinux wheels (numpy, onnxruntime, …) link against system
          # libstdc++/libgomp. NixOS doesn't ship those at standard paths;
          # nix-ld is enabled on this host but its global library set
          # doesn't include them. Pointing LD_LIBRARY_PATH directly at the
          # stdenv C++ runtime makes the wheels load.
          "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
        ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
