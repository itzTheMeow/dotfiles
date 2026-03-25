{
  config,
  xelib,
  ...
}:
let
  app = config.apps.linkwarden;

  OLLAMA_MODEL = "phi3:mini-4k";
in
{
  apps.linkwarden = {
    domain = "linkwarden.xela";
    port = 19283;
    enableProxy = true;
    details = {
      publicDomain = "linkwarden.xela.codes";
    };
  };

  services.linkwarden = {
    enable = true;
    host = app.ip;
    inherit (app) port;
    environment = {
      NEXTAUTH_URL = "${app.url}/api/v1/auth";
      # pocket id config
      NEXT_PUBLIC_KEYCLOAK_ENABLED = "true";
      KEYCLOAK_CUSTOM_NAME = "Pocket ID";
      KEYCLOAK_ISSUER = xelib.apps.pocket-id.url;
      # disable login for non-sso
      NEXT_PUBLIC_CREDENTIALS_ENABLED = "false";
      DISABLE_NEW_SSO_USERS = "true";
      # ollama ai tagging
      NEXT_PUBLIC_OLLAMA_ENDPOINT_URL = xelib.apps.ollama.url;
      inherit OLLAMA_MODEL;
    };
    environmentFile = config.sops.secrets.linkwarden.path;
  };
  systemd.services.linkwarden.after = [ "tailscale-online.service" ];

  # load ollama model
  services.ollama.loadModels = [ OLLAMA_MODEL ];

  sops.secrets.linkwarden = {
    format = "dotenv";
    sopsFile = config.sops.opSecrets.linkwarden.fullPath;
    key = "";
  };
  sops.opSecrets.linkwarden = {
    format = "dotenv";
    keys = {
      NEXTAUTH_SECRET = "op://Private/o3vngusljucwxvzstyguvucfiu/NEXTAUTH";
      KEYCLOAK_CLIENT_ID = "op://Private/o3vngusljucwxvzstyguvucfiu/xrj36alsgxvzq6kmtocoahg7qy/Client ID";
      KEYCLOAK_CLIENT_SECRET = "op://Private/o3vngusljucwxvzstyguvucfiu/xrj36alsgxvzq6kmtocoahg7qy/Client Secret";
    };
  };
}
