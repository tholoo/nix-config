{ ... }:
final: prev: {
  paperless-ngx = prev.paperless-ngx.overrideAttrs {
    doInstallCheck = false;
  };
}
