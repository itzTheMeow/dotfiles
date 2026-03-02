{
  buildGoModule,
  makeWrapper,
  pkgs-unstable,
  ...
}:
buildGoModule {
  name = "sops-build-secrets";
  src = ../go/sops-build-secrets;
  vendorHash = "sha256-tNp2+hiIcX2WJ3iyyRHXbcj7jvq6IoNfERQfQdhyFy0=";

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/sops-build-secrets \
      --set OP_SHARED_LIBRARY "${pkgs-unstable._1password-gui}/share/1password/libop_sdk_ipc_client.so"
  '';
}
