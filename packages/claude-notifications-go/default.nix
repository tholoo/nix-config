{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  libpulseaudio,
  alsa-lib,
}:
buildGoModule rec {
  pname = "claude-notifications-go";
  version = "1.38.0";

  src = fetchFromGitHub {
    owner = "777genius";
    repo = "claude-notifications-go";
    rev = "v${version}";
    hash = "sha256-0mUWhmxABnCytuYFDJ3fALO5RF2eCbCG9n4e67fgdIY=";
  };

  vendorHash = "sha256-uxkp08xQ0BrCcbmNFrG0k1DUFEoywSC3RVSvWno8gbk=";

  subPackages = [ "cmd/claude-notifications" ];

  # Module fetcher must avoid proxy.golang.org / sum.golang.org — the outbound
  # path here returns 403 / resets connections for some module zips. Direct VCS
  # fetches via github.com work. We override at preBuild because the drv-level
  # GOPROXY can be shadowed by the daemon's impureEnvVars passthrough.
  overrideModAttrs = _: {
    GOPROXY = "direct";
    GOSUMDB = "off";
    preBuild = ''
      export GOPROXY=direct
      export GOSUMDB=off
    '';
  };

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  nativeBuildInputs = [ makeWrapper ];

  # miniaudio (via gen2brain/malgo) dlopen()s libpulse.so.0 / libasound.so.2
  # at runtime. NixOS has no global loader path, so wrap to expose them.
  postFixup = ''
    wrapProgram $out/bin/claude-notifications \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libpulseaudio
          alsa-lib
        ]
      }
  '';

  meta = {
    description = "Smart desktop notifications for Claude Code (Go implementation)";
    homepage = "https://github.com/777genius/claude-notifications-go";
    license = lib.licenses.gpl3Only;
    mainProgram = "claude-notifications";
    platforms = lib.platforms.linux;
  };
}
