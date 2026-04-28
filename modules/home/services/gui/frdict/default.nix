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

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.fastapi
    ps.uvicorn
    ps.httpx
    ps.tqdm
  ]);

  projectDir = "${config.home.homeDirectory}/projects/french-learning/frdict";
  dbPath = "${config.home.homeDirectory}/.cache/frdict/french.sqlite";
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
    systemd.user.services.frdict = {
      Unit = {
        Description = "Local French dictionary HTTP service";
        # Skip the unit silently if the SQLite DB hasn't been built yet —
        # user runs `python build.py` to populate it.
        ConditionPathExists = dbPath;
        After = [ "default.target" ];
      };
      Service = {
        ExecStart = "${pythonEnv}/bin/python ${projectDir}/server.py";
        Restart = "on-failure";
        RestartSec = "5s";
        Environment = [
          "PYTHONUNBUFFERED=1"
          "FRDICT_DB=${dbPath}"
        ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
