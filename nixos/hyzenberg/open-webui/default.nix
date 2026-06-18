{ config, xelib, ... }:
let
  app = config.apps.open-webui;

  OLLAMA_MODEL = "qwen3:14b-q8_0";
in
{
  apps.open-webui = {
    domain = "openweb.xela";
    port = 12093;
    enableProxy = true;

    name = "Open WebUI";
    description = "AI web chat";
  };

  # load the model
  services.ollama.loadModels = [ OLLAMA_MODEL ];

  services.open-webui = {
    enable = true;
    host = app.ip;
    port = app.port;
    environment = {
      ENABLE_PERSISTENT_CONFIG = "False"; # only use declarative config
      WEBUI_URL = app.url;
      OLLAMA_BASE_URL = xelib.apps.ollama.url;
      ENABLE_OPENAI_API = "False";

      # oauth
      ENABLE_PASSWORD_AUTH = "False";
      ENABLE_LOGIN_FORM = "False";
      ENABLE_OAUTH_SIGNUP = "True";
      OAUTH_PROVIDER_NAME = "Pocket ID";
      OAUTH_SCOPES = "openid email profile groups";
      OAUTH_UPDATE_PICTURE_ON_LOGIN = "True";
      OPENID_PROVIDER_URL = "${xelib.apps.pocket-id.url}/.well-known/openid-configuration";
      OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";
      DEFAULT_USER_ROLE = "user"; # approve new users automatically

      BYPASS_MODEL_ACCESS_CONTROL = "True"; # all users get all models
      THREAD_POOL_SIZE = "2000"; # concurrency for production servers
      MCP_INITIALIZE_TIMEOUT = "45"; # allow MCP servers to take longer

      # analytics/stuff- undocumented but in the env example..
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";

      #ENABLE_WEB_SEARCH = "True";
      #WEB_SEARCH_ENGINE = "searxng";
      #SEARXNG_QUERY_URL = "http://127.0.0.1:8888/search?q=<query>&format=json";
    };
  };
  systemd.services.open-webui.after = [ "tailscale-online.service" ];

  sops.envFiles.open-webui = {
    WEBUI_SECRET_KEY = "op://Private/daxqfmcl234pjr7bunfn66ubhy/Secret Key";

    OAUTH_CLIENT_ID = "op://Private/daxqfmcl234pjr7bunfn66ubhy/OAuth Client ID";
    OAUTH_CLIENT_SECRET = "op://Private/daxqfmcl234pjr7bunfn66ubhy/OAuth Client Secret";
  };
}
