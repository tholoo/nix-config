{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
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
    "trafilatura"
  ];
  withFlags = lib.concatMapStringsSep " " (p: "--with ${p}") pythonDeps;

  proxyEnv = lib.optionals (cfg.proxy != null) [
    "HTTPS_PROXY=${cfg.proxy}"
    "HTTP_PROXY=${cfg.proxy}"
    "ALL_PROXY=${cfg.proxy}"
  ];
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "study"
    ];
  } // {
    port = mkOption {
      type = types.port;
      default = 8767;
      description = "Port frdict's HTTP service binds on 127.0.0.1.";
    };
    ankiConnectUrl = mkOption {
      type = types.str;
      default = "http://127.0.0.1:8765";
      description = "AnkiConnect base URL the /mine endpoint posts to.";
    };
    proxy = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "http://127.0.0.1:10808";
      description = ''
        Proxy URL exported as HTTPS_PROXY / HTTP_PROXY / ALL_PROXY so uv
        can fetch wheels on first launch. Leave null to inherit the
        system env (typical when no proxy is needed).
      '';
    };
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
        # Block "active" until /health responds, so `systemctl status frdict`
        # reflects reality and the first lookup after boot doesn't race the
        # server starting. --retry-connrefused keeps polling while the port
        # is still being bound; ~30s ceiling covers Piper model load.
        ExecStartPost = "${pkgs.curl}/bin/curl --retry 30 --retry-delay 1 --retry-connrefused -fsS http://127.0.0.1:${toString cfg.port}/health";
        Restart = "on-failure";
        # First launch may spend ~30s downloading wheels — give it room.
        RestartSec = "10s";
        Environment = [
          "PYTHONUNBUFFERED=1"
          "FRDICT_DB=${dbPath}"
          "FRDICT_PORT=${toString cfg.port}"
          "ANKI_URL=${cfg.ankiConnectUrl}"
          "HOME=${config.home.homeDirectory}"
          # Manylinux wheels (numpy, onnxruntime, …) link against system
          # libstdc++/libgomp. NixOS doesn't ship those at standard paths;
          # nix-ld is enabled on this host but its global library set
          # doesn't include them. Pointing LD_LIBRARY_PATH directly at the
          # stdenv C++ runtime makes the wheels load.
          "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
        ] ++ proxyEnv;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
