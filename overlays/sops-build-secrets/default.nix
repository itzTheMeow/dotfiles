final: prev: {
  sops-build-secrets = final.callPackage (
    {
      _1password-gui,
      buildGoModule,
      makeWrapper,
    }:
    buildGoModule {
      name = "sops-build-secrets";
      src = ./.;
      vendorHash = "sha256-tNp2+hiIcX2WJ3iyyRHXbcj7jvq6IoNfERQfQdhyFy0=";

      nativeBuildInputs = [ makeWrapper ];

      postInstall = ''
        wrapProgram $out/bin/sops-build-secrets \
          --set OP_SHARED_LIBRARY "${_1password-gui}/share/1password/libop_sdk_ipc_client.so"
      '';

      meta.mainProgram = "sops-build-secrets";
    }
  ) { };
}
