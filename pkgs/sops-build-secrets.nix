{
  _1password-gui,
  buildGoModule,
  makeWrapper,
}:
buildGoModule {
  name = "sops-build-secrets";
  src = ../go/sops-build-secrets;
  vendorHash = null;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/sops-build-secrets \
      --set OP_SHARED_LIBRARY "${_1password-gui}/share/1password/libop_sdk_ipc_client.so"
  '';
}
