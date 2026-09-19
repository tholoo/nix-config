{
  inputs,
  pkgs,
  ...
}:
let
  upstream = inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default;
  itijah = pkgs.fetchzip {
    url = "https://github.com/DiaaEddin/itijah/archive/refs/tags/v0.2.1.tar.gz";
    hash = "sha256-8fJHmSxRrlnD6u9P584RFIJwNDG+datYrtxHTLymlss=";
  };
  ucd = pkgs.fetchurl {
    url = "https://www.unicode.org/Public/zipped/16.0.0/UCD.zip";
    hash = "sha256-yG3YHysUpDsMwGSqX4mqckE4aAHjXFnHmE5XmDJjTrI=";
  };
in
upstream.overrideAttrs (old: {
  # The RTL branch adds itijah to build.zig.zon but omits it from the
  # generated Nix cache. Include its Unicode test data too: itijah's build
  # script requests that lazy dependency even when building as a library.
  # Remove this override once upstream regenerates build.zig.zon.nix.
  deps =
    pkgs.runCommand "ghostty-rtl-cache-${old.version}"
      {
        nativeBuildInputs = [ pkgs.zig_0_15 ];
      }
      ''
        mkdir -p "$out"
        cp -rs ${old.deps}/. "$out/"

        add_package() {
          actual="$(zig fetch --global-cache-dir "$TMPDIR" "$1")"
          if [ "$actual" != "$2" ]; then
            echo "Unexpected Zig package hash: $actual (expected $2)" >&2
            exit 1
          fi
          mv "$TMPDIR/p/$actual" "$out/$actual"
        }

        add_package ${itijah} itijah-0.2.1-keFZYfC1AwAKbdNB2ksZYamTycTESResjOdSkE40GkLX
        add_package ${ucd} N-V-__8AALTJcQJ3hosujokSgxYTsa3q1mDZ2dasYhuJwaOV
      '';
})
