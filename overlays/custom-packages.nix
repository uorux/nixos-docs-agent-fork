{ inputs, ... }:
final: prev: {
  zen-browser = inputs.zen-browser.packages.${final.stdenv.hostPlatform.system}.default;

  # Local change to xdg-desktop-portal, carried as a diff over nixpkgs' own pinned
  # source (currently 1.20.4) rather than a whole-source fork — so we inherit upstream
  # bumps for free and only maintain the delta.
  #
  # allow_other on the document-portal FUSE mount (substituteInPlace one-liner) so a
  # DEDICATED-uid sandbox app (running as app-<name>, not jrt) can read the doc://
  # files jrt's portal exports for it. The daemon still does its own per-app access
  # control in the FUSE handlers (this only lifts the kernel's mounting-uid-only
  # gate); NOT default_permissions, which would re-impose inode-uid checks and defeat
  # it. Requires programs.fuse.userAllowOther (fusermount3 rejects allow_other
  # otherwise — and the portal would then fail to mount at all).
  #
  # DISABLED (kept in-repo): xdg-desktop-portal-fallback.patch — the document-portal
  # fallback-access feature (inode-comparison app_has_file_access_fallback via
  # bwrapinfo.json). Turned off for now: it caused a writable-paths issue and nothing
  # currently depends on it. To re-enable, add it back to `patches` below. Regenerate
  # on a version bump with:
  #   git -C <fork> diff 2c75f6f..18f02f5 -- document-portal/document-portal.c
  #   (base 2c75f6f = upstream v1.20.4; head = otisdog8 fallback-improvements-120).
  #   Needs json-glib, which nixpkgs' portal already links — no buildInput change.
  xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace document-portal/document-portal-fuse.c \
        --replace-fail 'fsname=portal,auto_unmount",' 'fsname=portal,auto_unmount,allow_other",'
    '';
  });

  # nixpkgs pins several Electron apps (vesktop here) to pnpm 10.29.2, which is
  # marked insecure (CVE-2026-48995 + others). Swap the build-time pnpm for the
  # current secure 10.x so we remove the vulnerable package instead of
  # allow-listing it. Temporary until upstream fixes land (nixpkgs#536623).
  pnpm_10_29_2 = final.pnpm_10;

  # cantarell-fonts 0.311 fails to build on the nixos-* channels (otfautohint
  # errors on uni0424 during variable-font generation with afdko 5.0.1). The
  # nixpkgs-unstable branch has the fixed rebuild; pin from there. A font is
  # leaf data so cross-pinning is safe. Drop once the fix reaches nixos-unstable.
  cantarell-fonts =
    inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system}.cantarell-fonts;
}
