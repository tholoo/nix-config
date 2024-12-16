{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "calendar";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "calendar"
      "user"
    ];
  };

  config = mkIf cfg.enable {
    programs.vdirsyncer = {
      enable = true;
    };
    services.vdirsyncer = {
      enable = true;
    };
    programs.khal = {
      enable = true;
    };
    accounts.calendar = {
      basePath = ".calendar";
      accounts = {
        "ali0mhmz" = {
          primary = true;
          remote = {
            type = "google_calendar";
          };
          vdirsyncer = {
            enable = true;
            tokenFile = "~/secrets/access_tokens";
            collections = [
              "from a"
              "from b"
            ];

            clientIdCommand = [
              "pass"
              "work/gmail/vdirsyncer/clientid"
            ];
            clientSecretCommand = [
              "pass"
              "work/gmail/vdirsyncer/clientsecret"
            ];
          };
          khal = {
            enable = true;
            addresses = [ "ali0mhmz@gmail.com" ];
          };
        };
      };
    };
  };
}
