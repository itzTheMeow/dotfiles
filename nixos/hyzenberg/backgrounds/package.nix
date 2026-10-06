{
  buildGoModule,
  ...
}:
buildGoModule {
  name = "backgrounds";
  src = ./server;
  vendorHash = null;
}
