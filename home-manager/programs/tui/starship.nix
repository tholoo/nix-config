{ pkgs, ... }:
{
  programs.starship = {
    enable = true;
    settings = {
      kubernetes = {
        disabled = false;
        # detect_files = [ "k8s" ];
        contexts = [
          {
            context_pattern = ".*prod.*";
            style = "bold red";
            context_alias = "prod";
          }
          {
            context_pattern = ".*stag.*";
            style = "green";
            context_alias = "stage";
          }
        ];
      };
      # add_newline = false;
      # line_break.disabled = true;
    };
  };
}
