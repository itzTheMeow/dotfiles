{ config, host, ... }:
{
  sops.secrets.rustic_main = {
    sopsFile = config.sops.opSecrets.rustic.fullPath;
    owner = host.username;
  };
  sops.opSecrets.rustic = {
    keys = {
      rustic_main = "op://Private/6z2tlumg4aiznrno7mnryjunsq/password";
    };
  };
}
