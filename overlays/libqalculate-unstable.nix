#TODO:26.11 drop when nixpkgs has libqalculate 5.11.0+
final: prev: {
  libqalculate = final.unstable.libqalculate;
}
