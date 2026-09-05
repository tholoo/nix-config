{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  hyprland,
  grim,
  ydotool,
  wl-clipboard,
}:
stdenvNoCC.mkDerivation {
  pname = "agent-desktop";
  version = "1.0.0";
  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: type: baseNameOf path != "__pycache__" && !(lib.hasSuffix ".pyc" path);
  };
  nativeBuildInputs = [ makeWrapper ];
  doCheck = true;
  checkPhase = ''
    ${python3}/bin/python -m unittest discover -s tests
  '';
  installPhase = ''
    mkdir -p $out/libexec $out/bin
    cp agent_desktop.py $out/libexec/
    makeWrapper ${python3}/bin/python $out/bin/agent-desktop \
      --add-flags $out/libexec/agent_desktop.py \
      --prefix PATH : ${
        lib.makeBinPath [
          hyprland
          grim
          ydotool
          wl-clipboard
        ]
      } \
      --set-default YDOTOOL_SOCKET /run/ydotoold/socket
  '';
  meta = {
    description = "Window-targeted Hyprland desktop controls with JSON results";
    mainProgram = "agent-desktop";
    platforms = lib.platforms.linux;
  };
}
