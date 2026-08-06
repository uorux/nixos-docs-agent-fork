# Fleet-wide Prometheus node_exporter, bound to the host's tailnet IP only —
# the tailnet is the scrape path (the cluster's vmagent hits
# <host-tailnet-ip>:9100), and a bind-level restriction means the metrics
# socket simply doesn't exist on the LAN/internet, independent of firewall
# state (the k3s nodes still run with the firewall mkForce'd off).
#
# The k3s nodes (arquitens/carrack/munificent) already expose :9100 via the
# cluster's node-exporter DaemonSet on hostNetwork — a NixOS unit there would
# double-report the host. The enable default is therefore k3s-aware; everything
# else (recusant, galaxy, the laptops) gets the exporter on by default.
{
  config,
  lib,
  ...
}:
let
  cfg = config.modules.system.node-exporter;
  # The k3s module is only imported on cluster nodes, so probe for the option.
  hasK3s = config.modules.system ? k3s && config.modules.system.k3s.enable;
  # Tailnet IPs are stable per node (preserved in /var/lib/tailscale across
  # reinstalls), so a static map beats runtime discovery. Hosts not listed
  # (liveusb) fall back to loopback = effectively local-only.
  tailnetIp = {
    recusant = "100.110.239.45";
    galaxy = "100.101.3.42";
    constitution = "100.106.177.74";
    excelsior = "100.76.40.59";
    # k3s nodes listed for completeness; the exporter defaults off there.
    arquitens = "100.126.30.73";
    carrack = "100.103.225.29";
    munificent = "100.65.16.13";
  };
in
{
  options.modules.system.node-exporter = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = !hasK3s;
      defaultText = lib.literalExpression "!config.modules.system.k3s.enable";
      description = ''
        Run node_exporter on :9100 (scraped over the tailnet). Defaults off on
        k3s nodes, where the in-cluster node-exporter DaemonSet already owns
        hostPort 9100.
      '';
    };

    extraCollectors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "bcachefs" ];
      description = "Host-specific collectors appended to the fleet-wide base set.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = tailnetIp.${config.networking.hostName} or "127.0.0.1";
      defaultText = lib.literalExpression ''tailnetIp.''${hostname} or "127.0.0.1"'';
      description = "Address the exporter binds; the host's tailnet IP by default.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.node = {
      enable = true;
      inherit (cfg) listenAddress;
      # systemd:    per-unit state (failed/active) across all units.
      # processes:  aggregate process/thread counts by state.
      # interrupts/softirqs: per-CPU IRQ/softirq counts — spot IRQ storms.
      # ethtool:    NIC driver stats (drops/errors/ring).
      # qdisc:      network queueing-discipline stats (needs AF_NETLINK).
      # tcpstat:    TCP socket-state counts from /proc/net/tcp.
      # (PSI `pressure` collector is on by default → node_pressure_{cpu,memory,io}_*.)
      enabledCollectors = [
        "systemd"
        "processes"
        "interrupts"
        "softirqs"
        "ethtool"
        "qdisc"
        "tcpstat"
      ]
      ++ cfg.extraCollectors;
    };

    # Keep the exporter scrapeable when the host is under memory/CPU/IO pressure —
    # exactly when its metrics matter most. The module already sets Restart=always;
    # this adds OOM protection + scheduling priority + a cgroup memory floor.
    # (RestrictRealtime=true is hard-set by the module, so use Nice + best-effort
    # IO rather than a realtime class.)
    systemd.services.prometheus-node-exporter = {
      # Binding the tailnet IP needs tailscale0 up. Ordering covers the common
      # boot path; the restart settings cover the rest (tailscaled restart, slow
      # tailnet come-up) — keep retrying the bind forever instead of exhausting
      # the default start-limit burst.
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        RestartSec = "2s";
        OOMScoreAdjust = -900; # kernel OOM-killer avoids it
        Nice = -5; # CPU priority under load
        IOSchedulingClass = "best-effort";
        IOSchedulingPriority = 0; # disk collectors don't stall behind IO pressure
        MemoryLow = "48M"; # cgroup reclaim floor so it isn't evicted
      };
    };
  };
}
