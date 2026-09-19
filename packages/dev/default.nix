{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  git,
}:
stdenvNoCC.mkDerivation {
  pname = "dev-workspace";
  version = "1.0.0";
  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: type: baseNameOf path != "__pycache__" && !(lib.hasSuffix ".pyc" path);
  };
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ git ];
  doCheck = true;
  checkPhase = ''
    ${python3}/bin/python -m unittest discover -s tests -v
  '';
  installPhase = ''
    mkdir -p $out/bin $out/libexec
    cp dev.py $out/libexec/
    makeWrapper ${python3}/bin/python $out/bin/dev \
      --add-flags $out/libexec/dev.py \
      --prefix PATH : ${lib.makeBinPath [ git ]}
  '';
  meta = {
    description = "Per-worktree Zellij workspaces pairing an editor and coding agent";
    mainProgram = "dev";
    platforms = lib.platforms.linux;
  };
}
