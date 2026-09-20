{ configPath }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  edit = "${lib.getExe config.package} --headless -u NONE -i NONE -l ${./lazygit-edit.lua} \"$NVIM\"";
  integrationConfig = pkgs.writeText "nvim-lazygit.json" (
    builtins.toJSON {
      # Let LazyGit distinguish cancelling a dialog from leaving the application.
      quitOnTopLevelReturn = true;
      os = {
        edit = "${edit} {{filename}}";
        editAtLine = "${edit} {{filename}} {{line}}";
        editInTerminal = false;
      };
    }
  );
in
{
  plugins.lazygit = {
    enable = true;
    settings = {
      use_custom_config_file_path = 1;
      config_file_path = [
        configPath
        "${integrationConfig}"
      ];
    };
  };
  extraFiles."lua/editor/lazygit.lua".source = ./lazygit.lua;
  extraConfigLua = ''
    require("editor.lazygit").setup()
  '';
}
