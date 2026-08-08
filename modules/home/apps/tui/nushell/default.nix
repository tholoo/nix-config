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
        + (
          with pkgs;
          with lib;
          ''
            export def extract [name: string] {
              let lower_name = ($name | str downcase)

              let handlers = [
                [extension command args]
                ['tar\.bz2|tbz|tbz2' '${getExe gnutar}' ['xvjf']]
                ['tar\.gz|tgz'       '${getExe gnutar}' ['xvzf']]
                ['tar\.xz|txz'       '${getExe gnutar}' ['xvf']]
                ['tar\.Z'            '${getExe gnutar}' ['xvZf']]
                ['bz2'               '${getExe bzip2}'  ['-d']]
                ['deb'               '${getExe' binutils "ar"}' ['x']]
                ['gz'                '${getExe gzip}'   ['-d']]
                ['rar'               '${getExe unar}'   []]
                ['tar'               '${getExe gnutar}' ['xvf']]
                ['xz'                '${getExe' xz "xz"}' ['--decompress']]
                ['zip|war|jar|nupkg' '${getExe unzip}'  []]
                ['7z'                '${getExe' p7zip "7za"}' ['x']]
              ]

              let maybe_handler = (
                $handlers
                | where {|handler| $lower_name =~ $'\.($handler.extension)$' }
              )

              if ($maybe_handler | is-empty) {
                error make { msg: $"unsupported file extension: ($name)" }
              } else {
                let handler = ($maybe_handler | first)
                run-external $handler.command ...$handler.args $name
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
