{ pkgs, utils, ... }: {
  environment.systemPackages = with pkgs; [
    # runtimes
    nodejs_24
    tsx
    deno
    unstable.bun

    # package managers
    pnpm_10
    yarn
  ];

  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.denoland.vscode-deno # Deno
    nixpkgs.dbaeumer.vscode-eslint # ESLint
    nixpkgs.yoavbls.pretty-ts-errors # Pretty TypeScript Errors
    openvsx.oouo-diogo-perdigao.docthis # Document This
    openvsx.orta.vscode-jest # Jest
    marketplace.zengxingxin.sort-js-object-keys # Sort JS Object Keys
    marketplace.typescriptteam.native-preview # TypeScript 7
  ];

  home-manager.importUser = [
    (utils.vscodeSettings {
      eslint.useFlatConfig = true;
      "js/ts.updateImportsOnFileMove.enabled" = "always";
    })
    (utils.zedExtensions [ "deno" ])
  ];
}
