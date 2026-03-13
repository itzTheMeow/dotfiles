# NOTE: from https://github.com/NixOS/nixpkgs/pull/428353#issuecomment-3498917203
# more info in tv.nix nixos config
{
  cmake,
  fetchFromGitLab,
  #kdePackages,
  lib,
  pkg-config,
  pkgs-unstable,
  sdl3,
  libcec,
  ...
}:
let
  kdePackages = pkgs-unstable.kdePackages;
in
kdePackages.mkKdeDerivation rec {
  pname = "plasma-bigscreen";
  version = "unstable-2026-03-07";

  src = fetchFromGitLab {
    domain = "invent.kde.org";
    owner = "plasma";
    repo = "plasma-bigscreen";
    rev = "bd143fea7e386bac1652b8150a3ed3d5ef7cf93c";
    hash = "sha256-y439IX7e0+XqxqFj/4+P5le0hA7DiwA+smDsD0UH/fI=";
  };

  extraNativeBuildInputs = [
    cmake
    pkg-config
  ];

  # seems to be a pathing issue causing the lint to fail, but running is fine.
  # https://github.com/NixOS/nixpkgs/pull/428353#issuecomment-4019371029
  dontQmlLint = true;

  buildInputs =
    (with kdePackages; [
      bluez-qt
      kcmutils
      kdeclarative
      kdeconnect-kde
      ki18n
      kio
      knotifications
      kscreen
      kwayland
      kwindowsystem
      milou
      plasma-nano
      plasma-nm
      qtmultimedia
      qtwebengine
    ])
    # non-kde packages
    ++ [
      libcec
      pkgs-unstable.sdl3
    ];

  postPatch = ''
        substituteInPlace bin/plasma-bigscreen-wayland.in \
          --replace-fail @KDE_INSTALL_FULL_LIBEXECDIR@ "${kdePackages.plasma-workspace}/libexec"
        substituteInPlace bin/plasma-bigscreen-wayland.desktop.cmake \
          --replace-fail @CMAKE_INSTALL_FULL_LIBEXECDIR@ "${kdePackages.plasma-workspace}/libexec"

        # Plasma version numbers are required to match, but we are building an
        # unreleased package against a stable Plasma release.
        substituteInPlace CMakeLists.txt \
          --replace-fail 'set(PROJECT_VERSION "6.5.80")' 'set(PROJECT_VERSION "${kdePackages.plasma-workspace.version}")'

        # Fix for Qt 6.10+ which requires explicit find_package of private targets
        # Reference: https://github.com/NixOS/nixpkgs/pull/461599/changes
        substituteInPlace CMakeLists.txt \
          --replace-fail \
          'find_package(Qt6 ''${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS
        Quick
        Core
        Qml
        DBus
        Network
        Multimedia
        WebEngineCore
        WebEngineQuick
        WaylandClient
    )' \
          'find_package(Qt6 ''${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS
        Quick
        Core
        Qml
        QmlPrivate
        DBus
        Network
        Multimedia
        WebEngineCore
        WebEngineQuick
        WaylandClient
    )'
  '';

  preFixup = ''
    wrapQtApp $out/bin/plasma-bigscreen-wayland
  '';

  # fixes plasma-bigscreen-swap-session
  postInstall = ''
    QML_PATH="${lib.makeSearchPath "lib/qt-6/qml" buildInputs}"
    sed -i "/# Apply environment settings/i export QML2_IMPORT_PATH=\"$QML_PATH:\$QML2_IMPORT_PATH\"" $out/bin/plasma-bigscreen-common-env
  '';

  passthru.providedSessions = [
    "plasma-bigscreen-wayland"
  ];

  meta = {
    license = lib.licenses.gpl2Plus;
  };
}
