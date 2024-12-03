{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "kubecolor";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
      "kube"
    ];
  };

  config = mkIf cfg.enable {
    programs.${name} = {
      enable = true;
      enableAlias = true;
    };
  };
}
