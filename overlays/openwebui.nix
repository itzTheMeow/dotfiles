# Applies https://github.com/flexion/open-webui/pull/31 (adapted to the
# version of config.py pinned by nixpkgs) so OPENAI_API_CONFIGS is read
# from the environment as JSON, allowing per-connection prefix_id etc. to
# be configured declaratively with ENABLE_PERSISTENT_CONFIG=false.
# Upstream rejected this approach (open-webui#16562 / #19017) for some reason...
final: prev: {
  open-webui = prev.open-webui.overridePythonAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/open-webui-openai-api-configs.patch
    ];
  });
}
