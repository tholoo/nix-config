{ pkgs, lib, ... }: {
  programs.fzf = let
    excludes = lib.fold (el: c: "${c} --exclude ${el}" ) "" ["__pycache__"];
    tre_cmd = "${pkgs.tre-command}/bin/tre --color always {} --limit 5 --all";
    bat_cmd = "${pkgs.bat}/bin/bat --color always {}";
  in
  {
    enable = true;
    defaultCommand = "${pkgs.fd}/bin/fd --type f --hidden";

    changeDirWidgetCommand = "${pkgs.fd}/bin/fd --type d --hidden ${excludes}";
    changeDirWidgetOptions = [ "--preview '${tre_cmd} | head -100'" ];

    fileWidgetCommand = "${pkgs.fd}/bin/fd --hidden ${excludes}";
    fileWidgetOptions = [ "--preview '${bat_cmd} 2> /dev/null || ${tre_cmd} | head -100'" ];

    historyWidgetOptions = [ "--reverse" ];

    tmux.enableShellIntegration = false;
  };
}
