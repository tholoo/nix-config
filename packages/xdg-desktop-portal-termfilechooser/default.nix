{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  fetchpatch,
  meson,
  ninja,
  pkg-config,
  wayland-protocols,
  wayland-scanner,
  inih,
  libdrm,
  mesa,
  scdoc,
  systemd,
  wayland,
}:

stdenv.mkDerivation {
  pname = "xdg-desktop-portal-termfilechooser";
  version = "0-unstable-2025-01-29";

  src = fetchFromGitHub {
    owner = "hunkyburrito";
    repo = "xdg-desktop-portal-termfilechooser";
    rev = "2153e8b6fc1a0345374e5e220852595888d464a3";
    hash = "sha256-ITDH/Tq8BDjQcs+gxOed0j0gYeejAmmD1wiaXkA1arM=";
  };

  strictDeps = true;

  depsBuildBuild = [ pkg-config ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    scdoc
    wayland-scanner
    makeWrapper
  ];

  buildInputs = [
    inih
    libdrm
    mesa
    systemd
    wayland
    wayland-protocols
  ];

  mesonFlags = [
    (lib.mesonOption "sd-bus-provider" "libsystemd")
    (lib.mesonOption "sysconfdir" "/etc")
  ];

  postPatch = ''
    substituteInPlace src/core/config.c \
      --replace-fail '"/usr/local/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh"' '"${placeholder "out"}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh"'

    # Fix comparison between char and int
    # substituteInPlace src/filechooser/filechooser.c \
    #   --replace-fail 'char cr' 'int cr'
  '';

  meta = {
    homepage = "https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser";
    description = "Xdg-desktop-portal backend for wlroots and the likes of ranger";
    maintainers = with lib.maintainers; [ soispha ];
    platforms = lib.platforms.linux;
    license = lib.licenses.mit;
  };
}
