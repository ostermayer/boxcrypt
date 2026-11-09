# Reachable on the LAN, unable to reach anything else. See doc/modules/network.md.
{ config, lib, ... }:
let
  cfg = config.boxcrypt.network;
  dhcpServerPort = 67;
  dhcpClientPort = 68;
  mdnsPort = 5353;
  mdnsGroup = "224.0.0.251";
  igmpAllHosts = "224.0.0.1";
  igmpLeaveGroup = "224.0.0.2";
  igmpReports = "224.0.0.22";

  # Only the services that own these protocols may send on their ports.
  networkdUid = toString config.ids.uids.systemd-network;
  resolvedUid = toString config.ids.uids.systemd-resolve;
in
{
  options.boxcrypt.network.tcpPorts = lib.mkOption {
    type = lib.types.nonEmptyListOf lib.types.port;
    default = [ 443 ];
    description = "TCP ports accepted from private address ranges.";
  };

  config = {
    networking = {
      hostName = "boxcrypt";
      enableIPv6 = false;
      useNetworkd = true;
      useDHCP = false;
      nameservers = [ ];

      firewall.enable = false;
      nftables = {
        enable = true;
        ruleset = ''
          table inet boxcrypt {
            set lan {
              type ipv4_addr
              flags interval
              elements = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16 }
            }

            chain input {
              type filter hook input priority filter; policy drop;
              iif lo accept
              # Without this, a switch that filters multicast stops sending mDNS to the box.
              # Some switches send these queries from 0.0.0.0, so the source is not checked.
              ip protocol igmp ip daddr { ${igmpAllHosts}, ${mdnsGroup} } limit rate 20/second accept
              # Before the state rule, so established DHCP traffic is still rate limited.
              ip saddr @lan udp sport ${toString dhcpServerPort} udp dport ${toString dhcpClientPort} limit rate 20/second accept
              udp sport ${toString dhcpServerPort} udp dport ${toString dhcpClientPort} drop
              ct state established,related accept
              ct state invalid drop
              ip saddr @lan ip daddr ${mdnsGroup} udp dport ${toString mdnsPort} limit rate 20/second accept
              ip saddr @lan tcp dport { ${lib.concatMapStringsSep ", " toString cfg.tcpPorts} } accept
            }

            chain forward {
              type filter hook forward priority filter; policy drop;
            }

            chain output {
              type filter hook output priority filter; policy drop;
              oif lo accept
              # Before the state rule, so a recent lease cannot let another process use these ports.
              meta skuid ${networkdUid} udp sport ${toString dhcpClientPort} udp dport ${toString dhcpServerPort} ip daddr @lan accept
              meta skuid ${networkdUid} udp sport ${toString dhcpClientPort} udp dport ${toString dhcpServerPort} ip daddr 255.255.255.255 accept
              udp sport ${toString dhcpClientPort} udp dport ${toString dhcpServerPort} drop
              meta skuid ${resolvedUid} ip daddr ${mdnsGroup} udp sport ${toString mdnsPort} udp dport ${toString mdnsPort} accept
              # Some clients ask for the answer to come straight back to them.
              meta skuid ${resolvedUid} ip daddr @lan udp sport ${toString mdnsPort} limit rate 20/second accept
              udp sport ${toString mdnsPort} drop
              ct state established,related accept
              ip protocol igmp ip daddr { ${igmpLeaveGroup}, ${igmpReports}, ${mdnsGroup} } accept
            }
          }
        '';
      };
    };

    systemd.network = {
      wait-online.enable = false;
      networks."10-lan" = {
        # A USB network adapter could be an attacker's, so it is never configured.
        matchConfig = {
          Type = "ether wlan";
          Property = "!ID_BUS=usb";
        };
        networkConfig = {
          DHCP = "ipv4";
          LinkLocalAddressing = "no";
          IPv6AcceptRA = false;
          MulticastDNS = true;
        };
        # Take an address from DHCP and nothing else, least of all a way out.
        dhcpV4Config = {
          UseGateway = false;
          UseRoutes = false;
          UseDNS = false;
          UseNTP = false;
          UseHostname = false;
          SendHostname = false;
        };
      };
    };

    # If the firewall fails to load, the box must not come up on the network at all.
    # systemd-resolved starts too early to wait for the firewall. It needs no such order,
    # because no interface has an address until systemd-networkd has started.
    systemd.services.systemd-networkd = {
      requires = [ "nftables.service" ];
      after = [ "nftables.service" ];
    };

    # Answers for boxcrypt.local on the LAN, and looks up names nowhere else.
    services.resolved = {
      enable = true;
      settings.Resolve = {
        MulticastDNS = "yes";
        LLMNR = "no";
        DNSStubListener = "no";
        FallbackDNS = "";
      };
    };
    services.timesyncd.enable = false;
  };
}
