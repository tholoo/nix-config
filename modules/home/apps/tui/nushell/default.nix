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
  name = "nushell";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "shell"
    ];
  };

  config = mkIf cfg.enable {
    programs.nushell = {
      enable = true;
      environmentVariables = {
        EDITOR = "hx";
        SUDO_EDITOR = "hx";
      };

      configFile.text =
        builtins.readFile ./config.nu
        # nu
        + (
          with pkgs;
          with lib;
          ''
            export def extract [name:string] {
              let handlers = [ [extension command];
                               ['tar\.bz2|tbz|tbz2' '${getExe gnutar} xvjf']
                               ['tar\.gz|tgz'       '${getExe gnutar} xvzf']
                               ['tar\.xz|txz'       '${getExe gnutar} xvf']
                               ['tar\.Z'            '${getExe gnutar} xvZf']
                               ['bz2'               'bunzip2']
                               ['deb'               'ar x']
                               ['gz'                'gunzip']
                               ['pkg'               'pkgutil --expand']
                               ['rar'               '${getExe unrar} x']
                               ['tar'               '${getExe gnutar} xvf']
                               ['xz'                '${getExe' xz "xz"} --decompress']
                               ['zip|war|jar|nupkg' '${getExe unzip}']
                               ['Z'                 'uncompress']
                               ['7z'                '7za x']
                             ]
              let maybe_handler = ($handlers | where $name =~ $'\.(($it.extension))$')
              if ($maybe_handler | is-empty) {
                error make { msg: "unsupported file extension" }
              } else {
                let handler = ($maybe_handler | first)
                nu -c ($handler.command + ' ' + $name)
              }
            }
          ''
        );

      shellAliases = {
        lg = lib.getExe pkgs.lazygit;
        ld = lib.getExe pkgs.lazydocker;
        # mysync = "${lib.getExe pkgs.rsync} --progress --partial --human-readable --archive --verbose --exclude-from='${./rsync-excludes.txt}'";
        fetch = lib.getExe pkgs.fastfetch;
        cat = "${lib.getExe pkgs.bat} -n";
        db = "rainfrog";
      };
    };
  };
}
