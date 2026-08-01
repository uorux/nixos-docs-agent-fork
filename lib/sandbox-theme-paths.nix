# Single source of truth for the theme DATA a sandboxed GUI app needs bound in AND
# the system-profile links that make that data resolvable. Imported by BOTH sides so
# the bind side and the link side can never desync:
#   - lib/features/gui.nix binds /run/current-system/sw/<path> (read-only) into every
#     sandboxed GUI app, so GTK/Qt can find the theme its config names.
#   - nixos/modules/desktop/shared/theming.nix adds <path> to environment.pathsToLink
#     so /run/current-system/sw/<path> is actually populated from the theme packages.
# Previously these were two hand-maintained lists coupled only by comments; a trimmed
# pathsToLink (or a disabled theming module) silently un-themed every sandboxed app
# (Adwaita fallback) with no eval-time or runtime error. Keep them here, together.
[
  "/share/themes"
  "/share/Kvantum"
  "/share/icons"
]
