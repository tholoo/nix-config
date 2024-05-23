{
  options,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.mine.includeTags;
in
{
  options.mine.tags = {
    enabled = mkEnableOption "tags";
    include = [ ];
    exclude = [ ];
  };

  # config = mkIf cfg.enable {
  #
  # };
}
