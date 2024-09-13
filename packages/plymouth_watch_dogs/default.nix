{
  stdenvNoCC,
  fetchFromGitHub,
  unstableGitUpdater,
}:

stdenvNoCC.mkDerivation rec {
  pname = "plymouth-watch-dogs";
  name = pname;

  src = fetchFromGitHub {
    owner = "lukasbuehler";
    repo = "plymouth-watch_dogs-theme";
    rev = "673fd26569250196302e22fb0ba1e4b8d8201cb8";
    hash = "sha256-7OpqJRObbpP8xZvcyssynuxigqymTiWpW3BUctG8Lgk=";
  };

  postPatch = ''
    # Remove not needed files
    rm README.md
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/plymouth/themes/watch_dogs
    cp -r * $out/share/plymouth/themes/watch_dogs
    find $out/share/plymouth/themes/ -name \*.plymouth -exec sed -i "s@\/usr\/@$out\/@" {} \;
    runHook postInstall
  '';

  passthru.updateScript = unstableGitUpdater { };
}
