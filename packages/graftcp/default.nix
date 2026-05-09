{
  lib,
  buildGoModule,
  fetchurl,
}:

buildGoModule rec {
  pname = "graftcp";
  version = "0.7.4";

  src = fetchurl {
    url = "https://github.com/hmgle/graftcp/archive/v${version}.tar.gz";
    hash = "sha512-8RQ9l1mac8IPTspvjZnwyESqtgXWX2qsUbATPP2bQTnAcoaOL6YNrwo0B1VjjnZ8r6UYn9kjdt8bsPgsw1jLYw==";
  };

  modRoot = "local";
  vendorHash = "sha256-Nvw1XPcoHlKrUktXNb7KvCnaAKUJ3NEm9ZVSo5Jpsec=";

  subPackages = [
    "cmd/graftcp-local"
    "cmd/mgraftcp"
  ];

  env.CGO_ENABLED = 1;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${version}"
  ];

  preBuild = ''
    make -C .. VERSION=v${version} libgraftcp.a
  '';

  postInstall = ''
    make -C .. VERSION=v${version} graftcp
    install -Dm755 ../graftcp $out/bin/graftcp

    install -Dm644 ../README.md $out/share/doc/${pname}/README.md
    install -Dm644 ../README.zh-CN.md $out/share/doc/${pname}/README.zh-CN.md
    install -Dm644 ../example-graftcp.conf $out/share/doc/${pname}/example-graftcp.conf
    install -Dm644 ../example-blacklist-ip.txt $out/share/doc/${pname}/example-blacklist-ip.txt
    install -Dm644 ../example-whitelist-ip.txt $out/share/doc/${pname}/example-whitelist-ip.txt
    install -Dm644 example-graftcp-local.conf $out/share/doc/${pname}/example-graftcp-local.conf
  '';

  meta = {
    description = "Redirect a program's TCP traffic to a SOCKS5 or HTTP proxy";
    homepage = "https://github.com/hmgle/graftcp";
    license = lib.licenses.gpl3Plus;
    mainProgram = "graftcp";
    platforms = lib.platforms.linux;
  };
}
