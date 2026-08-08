{ pkgs, ... }: {
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    extensions =
      # officially packaged extensions
      (with pkgs.vscode-extensions; [
        pkgs.vscode-extensions."1Password".op-vscode # 1Password
        aaron-bond.better-comments # Better Comments #TODO: look into alternatives
        docker.docker # Docker DX
        editorconfig.editorconfig # EditorConfig
        esbenp.prettier-vscode # Prettier
        github.vscode-github-actions # GitHub Actions
        github.vscode-pull-request-github # GitHub Pull Requests
        jock.svg # SVG
        kilocode.kilo-code # Kilo Code
        mkhl.shfmt # shfmt
        ms-vscode.makefile-tools # Makefile Tools
        ms-vsliveshare.vsliveshare # Live Share
        nefrob.vscode-just-syntax # vscode-just
        redhat.vscode-xml # XML
        redhat.vscode-yaml # YAML
        tamasfe.even-better-toml # Even Better TOML
        timonwong.shellcheck # ShellCheck
        tomoki1207.pdf # vscode-pdf
        vadimcn.vscode-lldb # CodeLLDB
        wakatime.vscode-wakatime # WakaTime
        # C++
        ms-vscode.cpptools # C/C++
        ms-vscode.cmake-tools # CMake Tools
        # C#
        ms-dotnettools.vscode-dotnet-runtime # .NET Install Tool
        ms-dotnettools.csharp # C#
        # python
        ms-python.black-formatter # Black Formatter
        ms-python.isort # isort
        ms-python.debugpy # Python Debugger
        ms-python.python # Python
        ms-python.vscode-pylance # Pylance
        # dart/flutter
        dart-code.dart-code # Dart
        dart-code.flutter # Flutter
        # deno
        denoland.vscode-deno # Deno
        # js
        dbaeumer.vscode-eslint # ESLint
        yoavbls.pretty-ts-errors # Pretty TypeScript Errors
        # go
        golang.go # Go
        # godot
        geequlim.godot-tools # godot-tools
        # java
        redhat.java # Language Support for Java
        # swift
        llvm-vs-code-extensions.lldb-dap # LLDB DAP
        # nix
        jnoortheen.nix-ide # Nix IDE
        # html/css
        svelte.svelte-vscode # Svelte for VS Code
        bradlc.vscode-tailwindcss # Tailwind CSS IntelliSense
        tauri-apps.tauri-vscode # Tauri
        # themes
        zguolee.tabler-icons # Tabler Product Icons
        emmanuelbeziat.vscode-great-icons # VSCode Great Icons
        # vscode markdown preview look like gh
        bierner.markdown-checkbox # Markdown Checkboxes
        bierner.markdown-emoji # Markdown Emoji
        bierner.markdown-footnotes # Markdown Footnotes
        bierner.markdown-mermaid # Markdown Preview Mermaid Support
        bierner.markdown-preview-github-styles # Markdown Preview Github Styling
      ])
      # only on openvsx
      ++ (with pkgs.nix-vscode-extensions.open-vsx; [
        actboy168.tasks # Tasks
        antfu.iconify # Iconify IntelliSense
        coderabbit.coderabbit-vscode # CodeRabbit
        ctcuff.font-preview # Font Preview
        drblury.protobuf-vsc # Protobuf VSC
        mark-wiemer.vscode-autohotkey-plus-plus # AHK++
        mjmlio.vscode-mjml # MJML Official
        pascalreitermann93.vscode-yaml-sort # YAML Sort
        tyriar.luna-paint # Luna Paint
        vivaxy.vscode-conventional-commits # Conventional Commits
        # swift
        vknabel.vscode-swiftformat # SwiftFormat
        swiftlang.swift-vscode # Swift
        # js
        oouo-diogo-perdigao.docthis # Document This
        orta.vscode-jest # Jest
        # html/css
        csstools.postcss # PostCSS Language Support
        sysoev.language-stylus # stylus
        # python
        ms-python.vscode-python-envs # Python Environments
      ])
      # as a last resort use marketplace
      ++ (with pkgs.nix-vscode-extensions.vscode-marketplace; [
        activitywatch.aw-watcher-vscode # aw-watcher-vscode #TODO: deprecate
        alexcvzz.vscode-sqlite # SQLite
        fabiospampinato.vscode-diff # Diff
        #local-smart.excel-live-server # XVBA - Live Server VBA
        nickac.skriptinsight # Skript + SkriptInsight
        plibither8.remove-comments # Remove Comments
        pwabuilder.pwa-studio # PWABuilder Studio #TODO: deprecate
        # C++
        ms-vscode.cpp-devtools # C/C++ DevTools
        # go
        jinliming2.vscode-go-template # Go Template Support
        # html/css
        george-alisson.html-preview-vscode # HTML Preview
        # js
        zengxingxin.sort-js-object-keys # Sort JS Object Keys
        typescriptteam.native-preview # TypeScript 7
        # swift/ios
        ivhernandez.vscode-plist # Property List Editor
        # themes
        garytyler.darcula-pycharm # Darcula PyCharm Theme
        squarelogic.theme-bright-day # Bright Day Theme
        onecrayon.theme-quietlight-vsc # Quiet Light for VSC
        larxx.zero-theme # zero theme
        # also gh markdown stuff
        yahyabatulu.vscode-markdown-alert # Markdown Preview for Github Alerts
      ]);
  };
  services.vscode-server = {
    enable = true;
    installPath = "$HOME/.vscode";
  };
}
