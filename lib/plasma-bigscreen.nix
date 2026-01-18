# NOTE: from https://github.com/NixOS/nixpkgs/pull/428353#issuecomment-3498917203
# more info in tv.nix nixos config
{
  mkKdeDerivation,
  lib,
  fetchFromGitLab,
  pkg-config,
  ki18n,
  kdeclarative,
  kcmutils,
  knotifications,
  kio,
  kwayland,
  kwindowsystem,
  plasma-workspace,
  qtmultimedia,
  bluez-qt,
  qtwebengine,
  plasma-nano,
  plasma-nm,
  milou,
  kscreen,
  kdeconnect-kde,
}:
mkKdeDerivation {
  pname = "plasma-bigscreen";
  version = "unstable-2026-01-17";

  src = fetchFromGitLab {
    domain = "invent.kde.org";
    owner = "plasma";
    repo = "plasma-bigscreen";
    rev = "09beb0a668b27aa34ee8d023153fcabd5798bbd5";
    hash = "sha256-FQrIHOyfwUnwisDVrO8Y4fhQyu2X9FYpfM2X/BK41uc=";
  };

  extraNativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    ki18n
    kdeclarative
    kcmutils
    knotifications
    kio
    kwayland
    kwindowsystem
    plasma-workspace
    qtmultimedia
    bluez-qt
    qtwebengine
    plasma-nano
    plasma-nm
    milou
    kscreen
    kdeconnect-kde
  ];

  postPatch = ''
        substituteInPlace bin/plasma-bigscreen-wayland.in \
          --replace-fail @KDE_INSTALL_FULL_LIBEXECDIR@ "${plasma-workspace}/libexec"

        # Plasma version numbers are required to match, but we are building an
        # unreleased package against a stable Plasma release.
        substituteInPlace CMakeLists.txt \
          --replace-fail 'set(PROJECT_VERSION "6.4.80")' 'set(PROJECT_VERSION "${plasma-workspace.version}")'

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
    )'
  '';

  preFixup = ''
    wrapQtApp $out/bin/plasma-bigscreen-wayland
  '';

  passthru.providedSessions = [
    "plasma-bigscreen-wayland"
  ];

  meta = {
    license = lib.licenses.gpl2Plus;
  };
}
