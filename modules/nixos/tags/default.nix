{ config, lib, ... }:
let
  inherit (lib) mkOption types;
in
# cfg = config.mine.includeTags;
{
  options.mine.tags = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable tags.";
    };
    include = mkOption {
      type = with types; (listOf str);
      default = [ ];
      description = "tags to include";
    };
    exclude = mkOption {
      type = with types; (listOf str);
      default = [ ];
      description = "tags to exclude";
    };
  };

  # config = mkIf cfg.enable {
  #
  # };
}
