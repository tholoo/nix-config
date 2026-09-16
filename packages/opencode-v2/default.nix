{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # Reuse the existing Bun/NixOS packaging, replacing its old beta distribution.
  base = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;
in
base.overrideAttrs (old: {
  pname = "opencode";
  version = "2.0.4";
  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-2.0.4.tgz";
    hash = "sha512-qNJbkJ8cNI52C/zNjkYU8Nbc5mJ7iUjNmcESkoDHLCqsORgkuWNWVX/mdbSVfCf2Y39tn9oVJYVAipO4F2mMtA==";
  };

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/opencode $out/bin/opencode
    wrapProgram $out/bin/opencode --prefix PATH : ${lib.makeBinPath [ pkgs.ripgrep ]}
    runHook postInstall
  '';

  # The inherited updater targets the retired beta npm scope.
  passthru = builtins.removeAttrs (old.passthru or { }) [ "updater" ];
  meta = old.meta // {
    description = "OpenCode V2 terminal coding agent";
    longDescription = "OpenCode V2 with its normal TUI and minimal scrollback interface.";
    mainProgram = "opencode";
    downloadPage = "https://www.npmjs.com/package/@opencode/cli";
    platforms = [ "x86_64-linux" ];
  };
})
