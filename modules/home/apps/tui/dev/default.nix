{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.mine.dev;
  settings = (pkgs.formats.json { }).generate "dev-workspace.json" {
    inherit (cfg) agentCommand editorWidth;
    editorCommand = [ "${config.programs.nixvim.build.package}/bin/nvim" ];
    zellijCommand = lib.getExe config.programs.zellij.package;
    direnvCommand =
      if config.programs.direnv.enable then lib.getExe config.programs.direnv.package else null;
  };
  package = pkgs.writeShellScriptBin "dev" ''
    exec ${lib.getExe pkgs.mine.dev} --config ${settings} "$@"
  '';
in
{
  options.mine.dev = lib.mine.mkEnable config {
    tags = [
      "tui"
      "develop"
    ];
    agentCommand = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lib.optional config.mine.pi.enable (lib.getExe config.mine.pi.package);
      description = "Agent executable and arguments for dev workspaces; defaults to configured Pi.";
    };
    editorWidth = lib.mkOption {
      type = lib.types.ints.between 10 90;
      default = 60;
      description = "Percentage of workspace width given to Neovim.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = package;
      description = "Configured dev workspace launcher.";
    };
  };
  config = lib.mkIf (cfg.enable && config.mine.nixvim.enable && config.mine.zellij.enable) {
    assertions = [
      {
        assertion = (cfg.editorWidth - 5 * (builtins.div cfg.editorWidth 5)) == 0;
        message = "mine.dev.editorWidth must be a multiple of 5 (Zellij resize increments).";
      }
      {
        assertion = cfg.agentCommand != [ ];
        message = "mine.dev requires Pi or an explicit agentCommand.";
      }
    ];
    home.packages = [ package ];
  };
}
