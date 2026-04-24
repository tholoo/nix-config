{
  python3Packages,
  lib,
}:
python3Packages.buildPythonApplication {
  pname = "nix-modules-tui";
  version = "0.1.0";
  format = "other";

  src = ./.;

  propagatedBuildInputs = with python3Packages; [
    textual
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp nix-modules-tui.py $out/bin/nix-modules-tui
    chmod +x $out/bin/nix-modules-tui
    runHook postInstall
  '';

  meta = {
    description = "TUI for exploring NixOS/home-manager module enable states";
    mainProgram = "nix-modules-tui";
  };
}
