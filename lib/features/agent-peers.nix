# agent-peers — let every sandboxed AI agent drive the others as subagents.
#
# Each agent app on the nixpak backend keeps its creds/state in per-app stashes
# (/<tier>/sandbox/<app>/…, lib/storage.nix) that other sandboxes can't see. So
# `codex` run inside the claude-code sandbox dies at launch: the peer's wrapper
# (from system-bin.nix's /run/current-system/sw/bin) nests bwrap fine, but its
# HARD stash binds fail — "Can't find source path /persist/sandbox/codex/.codex".
#
# This feature binds every PEER agent's per-tier stash roots into the sandbox at
# their real absolute paths, read-write. That is deliberately all the peer's
# wrapper needs: it nests inside this sandbox and grafts its own stash onto its
# inner ~ itself, so the peer's storage list stays the single source of truth and
# the peer still runs with its own confinement (private /tmp, own binds). rw, not
# ro — agent CLIs write session/state/log files under their stash on startup.
#
# Soft binds (--bind-try): on a host where a peer app is disabled its stash root
# doesn't exist and the bind is skipped (the peer's wrapper isn't in sw/bin there
# either).
#
# SECURITY: this intentionally collapses the credential wall between the agents
# listed below — any of them can read/exfiltrate/overwrite any other's auth and
# state (that's what "use codex as a subagent" means). It does NOT expose
# non-agent sandboxes or anything outside /<tier>/sandbox/<peer>.
{ config, lib, ... }:
let
  # Every sandboxed AI agent app (app.name). Keep in sync with the apps that
  # import this feature — a name missing here means peers can't run that agent,
  # and an app not importing the feature can't run its peers.
  agents = [
    "claude-code"
    "codex"
    "gemini-cli"
    "gsd"
    "opencode"
  ];
  tiers = [
    "/persist"
    "/large"
    "/cache"
  ];
  peers = lib.filter (a: a != config.app.name) agents;
in
{
  imports = [ ../app-spec.nix ];

  config.app.nixpakModules = [
    (_: {
      bubblewrap.bind.rw = lib.concatMap (a: map (t: "${t}/sandbox/${a}") tiers) peers;
    })
  ];
}
