# disable coderabbit update checker... since we cant provide an option for this annoying popup :/
final: prev: {
  nix-vscode-extensions = prev.nix-vscode-extensions // {
    open-vsx = prev.nix-vscode-extensions.open-vsx // {
      coderabbit = prev.nix-vscode-extensions.open-vsx.coderabbit // {
        coderabbit-vscode =
          prev.nix-vscode-extensions.open-vsx.coderabbit.coderabbit-vscode.overrideAttrs
            (old: {
              postInstall = (old.postInstall or "") + ''
                f="$out/share/vscode/extensions/coderabbit.coderabbit-vscode/dist/extension.js"
                sed -i \
                  's#https://storage.googleapis.com/coderabbit_public_assets/coderabbit-vscode-metadata.json#http://127.0.0.1:1/coderabbit-no-update-check#g' \
                  "$f"
              '';
            });
      };
    };
  };
}
