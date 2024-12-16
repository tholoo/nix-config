{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "himalaya";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "email"
    ];
  };

  config = mkIf cfg.enable {
    accounts.email.accounts = {
      "ali0mhmz" = {
        address = "mohammadzadeh@yektanet.ir";
        flavor = "outlook.office365.com";
        himalaya.enable = true;

        primary = true;
        realName = "Ali Mohammadzadeh";
        imap.host = lib.mkForce "mail.yektanet.ir";
        smtp.host = lib.mkForce "mail.yektanet.ir";
        passwordCommand = "cat ~/pass/email.txt";
        mbsync = {
          enable = true;
          create = "maildir";
        };
        msmtp.enable = true;
      };
    };
    services.himalaya-watch = {
      enable = true;
    };
    programs.himalaya = {
      enable = true;
    };
  };
}
