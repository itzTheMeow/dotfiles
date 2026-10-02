{ pkgs, xelib, ... }:
{
  # editor
  diffEditor.maxComputationTime = 0;
  editor.codeActionsOnSave.source.fixAll = "explicit";
  editor.defaultFormatter = "esbenp.prettier-vscode";
  editor.fontFamily = xelib.globals.fonts.code.name;
  editor.formatOnSave = true;
  editor.minimap.enabled = false;
  editor.multiCursorModifier = "ctrlCmd";
  editor.stickyScroll.maxLineCount = 3;
  editor.tabSize = 2;
  files.exclude = {
    "**/.classpath" = true;
    "**/.factorypath" = true;
    "**/.project" = true;
    "**/.settings" = true;
  };

  # appearance
  explorer.confirmDelete = false;
  explorer.confirmDragAndDrop = false;
  explorer.confirmPasteNative = false;
  security.workspace.trust.untrustedFiles = "open";
  window.newWindowDimensions = "maximized";
  workbench.colorTheme = "Zero Theme";
  workbench.editorAssociations = {
    "*.sqlite" = "default";
    "*.svg" = "default";
    "*.ttf" = "font.detail.preview";
  };
  workbench.iconTheme = "vscode-great-icons";
  workbench.productIconTheme = "Tabler";
  workbench.startupEditor = "newUntitledFile";

  # terminal
  terminal.integrated.defaultProfile.linux = "zsh";
  terminal.integrated.fontFamily = xelib.globals.fonts.terminal.name;
  terminal.integrated.fontSize = 12;
  terminal.integrated.scrollback = 5000;
  terminal.integrated.tabs.showActions = "always";

  # git
  git.autofetch = true;
  git.confirmSync = false;
  git.enableSmartCommit = true;
  git.ignoreMissingGitWarning = true;
  git.openRepositoryInParentFolders = "never";
  git.path = "${pkgs.lib.getExe pkgs.git}";

  # github
  github.copilot.enable."*" = false;
  githubPullRequests.createOnPublishBranch = "never";
  githubPullRequests.pullBranch = "never";

  # toolchains
  C_Cpp.default.compilerPath = "${pkgs.lib.getExe pkgs.gcc}";
  C_Cpp.default.includePath = [
    "${pkgs.lib.getDev pkgs.glibc}/include"
    "\${workspaceFolder}/**"
  ];
  cmake.cmakePath = "${pkgs.lib.getExe pkgs.cmake}";
  java.configuration.runtimes = [
    {
      default = true;
      name = "JavaSE-21";
      path = "${pkgs.jdk21.home}";
    }
  ];
  java.jdt.ls.java.home = "${pkgs.jdk21.home}";
  makefile.configureOnOpen = false;
  python.defaultInterpreterPath = "python3";

  # languages
  "1password.editor.suggestStorage" = false;
  csharp.suppressDotnetInstallWarning = true;
  css.lint.unknownAtRules = "ignore";
  dart.checkForSdkUpdates = false;
  dart.hotReloadOnSave = "manual";
  dart.projectSearchDepth = 2;
  docker.extension.enableComposeLanguageServer = false;
  dotnet.formatting.organizeImportsOnFormat = true;
  eslint.useFlatConfig = true;
  go.diagnostic.vulncheck = "Imports";
  go.toolsManagement.autoUpdate = true;
  go-template.languages = [ "shellscript" ];
  godotTools.lsp.serverPort = 6005;
  iconify.inplace = false;
  "js/ts.updateImportsOnFileMove.enabled" = "always";
  jest.runMode = "on-demand";
  lldb.suppressUpdateNotifications = true;
  liveshare.connectionMode = "relay";
  liveshare.focusBehavior = "prompt";
  liveshare.shareExternalFiles = false;
  nix.enableLanguageServer = true;
  nix.serverSettings.nixd.formatting.command = [ "${pkgs.lib.getExe pkgs.nixfmt}" ];
  prettier.printWidth = 100;
  protobuf.formatOnSave = true;
  python.analysis.autoImportCompletions = true;
  scss.lint.unknownAtRules = "ignore";
  svelte.enable-ts-plugin = true;
  tailwindCSS.classAttributes = [
    "class"
    "className"
    "ngClass"
    "hover"
    "width"
    "height"
    "classes"
    "background"
    "contentBase"
  ];
  vscode-yaml-sort.forceQuotes = true;
  vscode-yaml-sort.noCompatMode = true;
  vscode-yaml-sort.notifySuccess = false;
  vscode-yaml-sort.quotingType = "\"";
  vscode-yaml-sort.sortOnSave = -1;

  # language formatters
  "[c]".editor.defaultFormatter = "ms-vscode.cpptools";
  "[cpp]".editor.defaultFormatter = "ms-vscode.cpptools";
  "[dart]".editor = {
    rulers = [ 80 ];
    selectionHighlight = false;
    tabCompletion = "onlySnippets";
  };
  "[dockercompose]".editor = {
    autoIndent = "advanced";
    defaultFormatter = "redhat.vscode-yaml";
    insertSpaces = true;
    tabSize = 2;
  };
  "[gdscript]".editor.defaultFormatter = "geequlim.godot-tools";
  "[github-actions-workflow]".editor.defaultFormatter = "redhat.vscode-yaml";
  "[go]".editor.defaultFormatter = "golang.go";
  "[java]".editor = {
    codeActionsOnSave.source.organizeImports = "always";
    defaultFormatter = "redhat.java";
  };
  "[just]".editor.defaultFormatter = "nefrob.vscode-just-syntax";
  "[nix]".editor.defaultFormatter = "jnoortheen.nix-ide";
  "[proto]".editor.defaultFormatter = "DrBlury.protobuf-vsc";
  "[proto3]".editor.defaultFormatter = "DrBlury.protobuf-vsc";
  "[python]".editor.defaultFormatter = "ms-python.black-formatter";
  "[shellscript]".editor.defaultFormatter = "mkhl.shfmt";
  "[svelte]".editor.defaultFormatter = "svelte.svelte-vscode";
  "[svg]".editor.defaultFormatter = "jock.svg";
  "[toml]".editor.defaultFormatter = "tamasfe.even-better-toml";
  "[xml]".editor.defaultFormatter = "redhat.vscode-xml";

  # chat/ai
  chat.mcp.gallery.enabled = true;
  chat.tips.enabled = false;
  chat.viewSessions.enabled = false;
  chat.viewSessions.orientation = "stacked";
  coderabbit.autoReviewMode = "disabled";

  # updates
  extensions.autoUpdate = false;
  update.mode = "none";
}
