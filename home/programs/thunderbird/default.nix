{ ... }:
{
  programs.thunderbird = {
    enable = true;
    profiles.default = {
      isDefault = true;
    };
  };
  catppuccin.thunderbird.enable = true;

  accounts = {
    email = {
      accounts."alex@xela.codes" = {
        address = "alex@xela.codes";
        realName = "Alex";
        userName = "alex@xela.codes";
        imap = {
          host = "mail.xela.codes";
          port = 993;
        };
        smtp = {
          host = "mail.xela.codes";
          port = 465;
        };
        primary = true;
        thunderbird.enable = true;
      };
    };
    contact = {
      accounts.Contacts = {
        remote = {
          type = "carddav";
          url = "https://mail.xela.codes/SOGo/dav/alex@xela.codes/Contacts/personal/";
          userName = "alex@xela.codes";
        };
        thunderbird.enable = true;
      };
    };
  };
}
