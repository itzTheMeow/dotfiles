let
  # shorthand to unbind a ctrl+k chord
  chord = when: key: command: {
    key = "ctrl+k ${key}";
    command = "-${command}";
    inherit when;
  };
  # direct binding; prefix command with "-" to unbind
  plain = when: key: command: {
    inherit key command when;
  };

  edit = "editorTextFocus && !editorReadonly";
  fold = "editorTextFocus && foldingEnabled";
  focus = "editorTextFocus";
  diff = "isInDiffEditor";
  keybind = "inKeybindings && keybindingFocus";
  view = "focusedView != ''";
in
[
  # quick open
  (plain null "ctrl+k" "workbench.action.quickOpen")
  (plain null "ctrl+p" "-workbench.action.quickOpen")

  # rename & change-all
  (plain edit "f2" "editor.action.changeAll")
  (plain edit "ctrl+f2" "-editor.action.changeAll")
  (plain "editorHasRenameProvider && editorTextFocus && !editorReadonly" "shift+f2"
    "editor.action.rename"
  )
  (plain "editorHasRenameProvider && editorTextFocus && !editorReadonly" "f2" "-editor.action.rename")

  # build
  (plain null "ctrl+/" "workbench.action.tasks.build")
  (plain edit "ctrl+/" "-editor.action.commentLine")
  (plain "suggestWidgetVisible" "ctrl+/" "-toggleExplainMode")
  (plain null "ctrl+shift+b" "-workbench.action.tasks.build")

  # sort
  (plain edit "f7" "editor.action.sortLinesAscending")
  (plain "editorTextFocus && hasWordHighlights" "f7" "-editor.action.wordHighlight.next")
  (plain "editorTextFocus && hasWordHighlights" "shift+f7" "-editor.action.wordHighlight.prev")
  (plain null "f8" "sortJsObjectKeys.sortJsObjectKeys")
  (plain null "alt+s" "-sortJsObjectKeys.sortJsObjectKeys")
  (plain "luna:focused && activeCustomEditorId == 'luna.editor' && focusedView == ''" "f8"
    "-luna.color.toggleColorsWindow"
  )
  (plain "editorFocus" "f8" "-editor.action.marker.nextInFiles")

  # open & save
  (plain "true" "ctrl+o" "-workbench.action.files.openFile")
  (plain "remoteFileDialogVisible" "ctrl+shift+s" "-workbench.action.files.saveLocalFile")
  (plain null "ctrl+shift+s" "-workbench.action.files.saveAs")
  (chord null "ctrl+shift+s" "workbench.action.files.saveWithoutFormatting")
  (plain null "ctrl+shift+s" "workbench.action.files.saveWithoutFormatting")

  # reload
  (plain null "ctrl+r" "-workbench.action.openRecent")
  (plain null "ctrl+r" "workbench.action.reloadWindow")
  (plain "isDevelopment" "ctrl+r" "-workbench.action.reloadWindow")

  # symbols
  (plain "!accessibilityHelpIsShown && !accessibleViewIsShown" "ctrl+shift+k"
    "workbench.action.gotoSymbol"
  )
  (plain "!accessibilityHelpIsShown && !accessibleViewIsShown" "ctrl+shift+o"
    "-workbench.action.gotoSymbol"
  )
  (plain null "ctrl+shift+alt+k" "workbench.action.showAllSymbols")
  (plain null "ctrl+t" "-workbench.action.showAllSymbols")
  (plain "textInputFocus && !editorReadonly" "ctrl+shift+k" "-editor.action.deleteLines")

  # unbind all of the ctrl+k chords for quick open
  (chord fold "ctrl+1" "editor.foldLevel1")
  (chord fold "ctrl+2" "editor.foldLevel2")
  (chord fold "ctrl+3" "editor.foldLevel3")
  (chord fold "ctrl+4" "editor.foldLevel4")
  (chord fold "ctrl+5" "editor.foldLevel5")
  (chord fold "ctrl+6" "editor.foldLevel6")
  (chord fold "ctrl+7" "editor.foldLevel7")
  (chord fold "ctrl+0" "editor.foldAll")
  (chord fold "ctrl+-" "editor.foldAllExcept")
  (chord fold "ctrl+/" "editor.foldAllBlockComments")
  (chord fold "ctrl+8" "editor.foldAllMarkerRegions")
  (chord fold "ctrl+[" "editor.foldRecursively")
  (chord fold "ctrl+]" "editor.unfoldRecursively")
  (chord fold "ctrl+9" "editor.unfoldAllMarkerRegions")
  (chord fold "ctrl+=" "editor.unfoldAllExcept")
  (chord fold "ctrl+j" "editor.unfoldAll")
  (chord fold "ctrl+l" "editor.toggleFold")
  (chord fold "ctrl+," "editor.createFoldingRangeFromSelection")
  (chord fold "ctrl+." "editor.removeManualFoldingRanges")
  (chord edit "ctrl+c" "editor.action.addCommentLine")
  (chord edit "ctrl+u" "editor.action.removeCommentLine")
  (chord edit "ctrl+x" "editor.action.trimTrailingWhitespace")
  (chord "editorTextFocus && selectionAnchorSet" "ctrl+k" "editor.action.selectFromAnchorToCursor")
  (chord focus "ctrl+b" "editor.action.setSelectionAnchor")
  (chord focus "ctrl+i" "editor.action.showHover")
  (chord "editorFocus" "ctrl+d" "editor.action.moveSelectionToNextFindMatch")
  (chord "editorHasDocumentSelectionFormattingProvider && editorTextFocus && !editorReadonly" "ctrl+f"
    "editor.action.formatSelection"
  )
  (chord "editorTextFocus && inDebugMode" "ctrl+i" "editor.debug.action.showDebugHover")
  (chord "!notebookEditorFocused" "m" "workbench.action.editor.changeLanguageMode")
  (chord null "ctrl+pagedown" "workbench.action.nextEditorInGroup")
  (chord null "ctrl+pageup" "workbench.action.previousEditorInGroup")
  (chord null "ctrl+p" "workbench.action.showAllEditors")
  (chord null "ctrl+up" "workbench.action.focusAboveGroup")
  (chord null "ctrl+down" "workbench.action.focusBelowGroup")
  (chord null "ctrl+left" "workbench.action.focusLeftGroup")
  (chord null "ctrl+right" "workbench.action.focusRightGroup")
  (chord null "up" "workbench.action.moveActiveEditorGroupUp")
  (chord null "down" "workbench.action.moveActiveEditorGroupDown")
  (chord null "left" "workbench.action.moveActiveEditorGroupLeft")
  (chord null "right" "workbench.action.moveActiveEditorGroupRight")
  (chord "sideBySideEditorActive" "ctrl+shift+\\" "workbench.action.joinEditorInGroup")
  (chord "activeEditorCanSplitInGroup" "ctrl+shift+\\" "workbench.action.splitEditorInGroup")
  (chord null "ctrl+\\" "workbench.action.splitEditorOrthogonal")
  (chord null "enter" "workbench.action.keepEditor")
  (chord "!activeEditorIsPinned" "shift+enter" "workbench.action.pinEditor")
  (chord "activeEditorIsPinned" "shift+enter" "workbench.action.unpinEditor")
  (chord null "ctrl+q" "workbench.action.navigateToLastEditLocation")
  (chord null "ctrl+shift+w" "workbench.action.closeAllGroups")
  (chord null "ctrl+w" "workbench.action.closeAllEditors")
  (chord null "w" "workbench.action.closeEditorsInGroup")
  (chord null "u" "workbench.action.closeUnmodifiedEditors")
  (chord null "c" "workbench.files.action.compareWithClipboard")
  (chord null "d" "workbench.files.action.compareWithSaved")
  (chord "editorFocus" "ctrl+alt+c" "copyFilePath")
  (chord "editorFocus" "ctrl+shift+alt+c" "copyRelativeFilePath")
  (chord null "p" "workbench.action.files.copyPathOfActiveFile")
  (chord null "r" "workbench.action.files.revealActiveFileInWindows")
  (chord "emptyWorkspaceSupport && workbenchState != 'empty'" "f" "workbench.action.closeFolder")
  (chord "emptyWorkspaceSupport" "o" "workbench.action.files.showOpenedFileInNewWindow")
  (chord "openFolderWorkspaceSupport" "ctrl+o" "workbench.action.files.openFolder")
  (chord "remoteFileDialogVisible" "ctrl+o" "workbench.action.files.openLocalFolder")
  (chord "workbench.explorer.openEditorsView.active" "e"
    "workbench.files.action.focusOpenEditorsView"
  )
  (chord diff "ctrl+r" "git.revertSelectedRanges")
  (chord diff "ctrl+alt+s" "git.stageSelectedRanges")
  (chord diff "ctrl+n" "git.unstageSelectedRanges")
  (chord "notebookCellListFocused && !inputFocus && !notebookCellInputIsCollapsed" "ctrl+c"
    "notebook.cell.collapseCellInput"
  )
  (chord "notebookCellInputIsCollapsed && notebookCellListFocused" "ctrl+c"
    "notebook.cell.expandCellInput"
  )
  (chord
    "notebookCellHasOutputs && notebookCellListFocused && !inputFocus && !notebookCellOutputIsCollapsed"
    "t"
    "notebook.cell.collapseCellOutput"
  )
  (chord "notebookCellListFocused && notebookCellOutputIsCollapsed" "t"
    "notebook.cell.expandCellOutput"
  )
  (chord "notebookCellEditable && notebookEditable && notebookEditorFocused" "ctrl+shift+\\"
    "notebook.cell.split"
  )
  (chord "editorTextFocus && !editorReadonly && editorLangId == 'jsonc'" "ctrl+k"
    "editor.action.defineKeybinding"
  )
  (chord keybind "ctrl+a" "keybindings.editor.addKeybinding")
  (chord keybind "ctrl+e" "keybindings.editor.defineWhenExpression")
  (chord null "ctrl+s" "workbench.action.openGlobalKeybindings")
  (chord null "ctrl+r" "workbench.action.keybindingsReference")
  (chord "inReferenceSearchEditor || referenceSearchVisible" "f2" "togglePeekWidgetFocus")
  (chord view "down" "views.moveViewDown")
  (chord view "left" "views.moveViewLeft")
  (chord view "right" "views.moveViewRight")
  (chord view "up" "views.moveViewUp")
  (chord "workbench.panel.output.active" "ctrl+h" "workbench.action.output.toggleOutput")
  (chord "!notebookEditorFocused && editorLangId == 'markdown'" "v" "markdown.showPreviewToSide")
  (chord "editorHasDefinitionProvider && editorTextFocus && !isInEmbeddedEditor" "f12"
    "editor.action.revealDefinitionAside"
  )
  (chord null "ctrl+t" "workbench.action.selectTheme")
  (chord null "z" "workbench.action.toggleZenMode")
]
