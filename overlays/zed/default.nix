# TODO:26.11 drop the `final.unstable.` prefix once stable ships a compatible zed.
final: prev: {
  zed-editor = final.unstable.zed-editor.overrideAttrs (old: {
    # ctrl-enter commits untracked files too when nothing is staged
    patches = (old.patches or [ ]) ++ [ ./commit-untracked.patch ];
  });
}
