{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    getExe'
    mkIf
    mkMerge
    mkOption
    types
    ;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "vigiland";
  package = inputs.vigiland.packages.${pkgs.stdenv.hostPlatform.system}.vigiland;
  controlPackage = pkgs.writeShellApplication {
    name = "vigiland-control";
    runtimeInputs = with pkgs; [
      coreutils
      procps
      util-linux
    ];
    text = ''
      user_id="$(id -u)"

      is_active() {
        pgrep -u "$user_id" -x vigiland > /dev/null
      }

      show_status() {
        if is_active; then
          printf '%s\n' '{"alt":"active","state":"On","tooltip":"Vigiland is active; click to allow idle"}'
        else
          printf '%s\n' '{"alt":"inactive","state":"Off","tooltip":"Vigiland is inactive; click to inhibit idle"}'
        fi
      }

      show_message() {
        if is_active; then
          printf '%s\n' 'Vigiland enabled; idle is inhibited'
        else
          printf '%s\n' 'Vigiland disabled; idle is allowed'
        fi
      }

      toggle() {
        runtime_dir="''${XDG_RUNTIME_DIR:-/tmp}"
        exec 9>"$runtime_dir/vigiland-control-$user_id.lock"
        flock -x 9

        if is_active; then
          pkill -u "$user_id" -x vigiland || true
          for _ in {1..20}; do
            is_active || break
            sleep 0.05
          done
        else
          nohup ${getExe' package "vigiland"} > /dev/null 2>&1 9>&- &
          for _ in {1..20}; do
            is_active && break
            sleep 0.05
          done
        fi
      }

      case "''${1:-status}" in
        status)
          show_status
          ;;
        toggle)
          toggle
          ;;
        toggle-message)
          toggle
          show_message
          ;;
        *)
          printf 'usage: vigiland-control {status|toggle|toggle-message}\n' >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  options.mine.${name} =
    (mkEnable config {
      tags = [
        "gui"
        "window-manager"
        "hypr"
      ];
    })
    // {
      controlPackage = mkOption {
        type = types.package;
        readOnly = true;
        internal = true;
        description = "Shared Vigiland status and toggle controller.";
      };
    };

  config = mkMerge [
    { mine.${name}.controlPackage = controlPackage; }
    (mkIf cfg.enable {
      home.packages = [
        package
        controlPackage
      ];
    })
  ];
}
