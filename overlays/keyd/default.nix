{ channels, ... }:
final: prev: {
  keyd = prev.keyd.overrideAttrs (oldAttrs: {
    version = "2.4.99";
    src = final.fetchFromGitHub {
      owner = "rvaiya";
      repo = "keyd";
      rev = "02c77af7861a28927cc948d93e5477198bc0c933";
      hash = "sha256-rPxC+amLHUM39aX03KIWClgz4oHtQZiQI6svEL2AzHA=";
    };
    postPatch = ''
      substituteInPlace Makefile \
        --replace /usr/local ""

      substituteInPlace keyd.service.in \
        --replace @PREFIX@/bin $out/bin
    '';
  });
}
