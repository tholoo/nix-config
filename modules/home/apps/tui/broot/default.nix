{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "broot";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "shell"
      "interactive"
    ];
  };

  config = mkIf cfg.enable {
    programs.${name} = {
      enable = true;
      enableNushellIntegration = false; # broken
      settings = {
        modal = true;
        verbs = [
          {
            invocation = "p";
            execution = ":parent";
          }
          {
            invocation = "edit";
            shortcut = "e";
            key = "ctrl-e";
            apply_to = "text_file";
            execution = "$EDITOR {file}";
            leave_broot = "true";
          }
        ];
      };
    };
  };
}
