let
  # shorthand for binding keys within a context; null context is global
  bind =
    context: bindings: (if context == null then { } else { inherit context; }) // { inherit bindings; };
  # shorthand for dropping default bindings within a context
  unbind =
    context: dropped: (if context == null then { } else { inherit context; }) // { unbind = dropped; };
in
[
  # rename & select-all-matches
  (bind "Editor" { "shift-f2" = "editor::Rename"; })
  (unbind "Editor" { "f2" = "editor::Rename"; })
  (bind "Editor" { "f2" = "editor::SelectAllMatches"; })
  (unbind "Editor" { "ctrl-f2" = "editor::SelectAllMatches"; })

  # sort
  (bind null { "f7" = "editor::SortLinesCaseInsensitive"; })

  # delete files
  (bind "ProjectPanel" { "delete" = "project_panel::Delete"; })
  (unbind "ProjectPanel" { "delete" = "project_panel::Trash"; })

  # quick open on ctrl-k
  (bind "Workspace" { "ctrl-k" = "file_finder::Toggle"; })
  (unbind "Workspace" { "ctrl-p" = "file_finder::Toggle"; })
  (bind "FileFinder || FileFinder > Picker > Editor" { "ctrl-k" = "file_finder::Toggle"; })
  (unbind "FileFinder || FileFinder > Picker > Editor" { "ctrl-p" = "file_finder::Toggle"; })

  # save without formatting
  (unbind "Workspace" { "ctrl-shift-s" = "workspace::SaveAs"; })
  (bind "Workspace" { "ctrl-shift-s" = "workspace::SaveWithoutFormat"; })
  (unbind "Workspace" { "ctrl-k s" = "workspace::SaveWithoutFormat"; })

  # reload
  (bind null { "ctrl-r" = "workspace::Reload"; })
]
