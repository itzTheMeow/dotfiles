{
  config,
  xelib,
  ...
}:
let
  svc = xelib.services.linkwarden;
  host = xelib.hosts.${svc.host}.ip;

  ollama = xelib.services.ollama;
  OLLAMA_MODEL = "phi3:mini-4k";
in
{
  services.linkwarden = {
    enable = true;
    inherit host;
    inherit (svc) port;
    environment = {
      NEXTAUTH_URL = "https://${svc.domain}/api/v1/auth";
      # pocket id config
      NEXT_PUBLIC_KEYCLOAK_ENABLED = "true";
      KEYCLOAK_CUSTOM_NAME = "Pocket ID";
      KEYCLOAK_ISSUER = "https://${xelib.services.pocket-id.domain}";
      # disable login for non-sso
      NEXT_PUBLIC_CREDENTIALS_ENABLED = "false";
      DISABLE_NEW_SSO_USERS = "true";
      # ollama ai tagging
      NEXT_PUBLIC_OLLAMA_ENDPOINT_URL = "http://${xelib.hosts.${ollama.host}.ip}:${toString ollama.port}";
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

  nginx.proxy.${svc.domain}.target.port = svc.port;
}
