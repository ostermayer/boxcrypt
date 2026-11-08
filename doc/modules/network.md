# Network

> **Status: firewall and routing are built and VM-tested.** Address pinning and app
> ports are still to come. See ADR-013.

## Purpose

Make the box reachable on the LAN and unable to reach anything else.

## Behaviour

| Direction | Rule |
|---|---|
| Inbound | TCP 443 from private address ranges, and DHCP replies |
| Outbound | Replies to established connections, and DHCP |
| Forwarding | None |
| Routing | DHCP gateway ignored, so no default route |
| IPv6 | Disabled |
| Wi-Fi | Off unless the owner chooses it |
| Bluetooth | Always off |

Enabling an add-on app adds its port to the inbound rule, and disabling it removes the
port.

The box takes an address by DHCP during setup, and the wizard then pins it as static
so the address and certificate stay stable. A restored box reuses that address.

## Wi-Fi

Wired is the default and the recommendation. An owner without a cable can choose Wi-Fi
on the box's screen, which needs a monitor and keyboard once.

- Until then, a gate on `cfg80211` stops every Wi-Fi driver from loading, and `iwd` does
  not start.
- Choosing Wi-Fi creates `/persist/network/wifi-enabled`.
- The box joins as a client only. The same firewall and no-gateway rules apply.
- The network password is stored unencrypted in `/persist/network/iwd`, because the box
  must join before it can show the unlock page. A stolen box reveals it.

## Module options

| Option | Default | Purpose |
|---|---|---|
| `cryptbox.network.tcpPorts` | `[ 443 ]` | Ports accepted from private ranges |

## Edge cases

- **Address already in use at restore:** the box warns and offers a new address, which
  means trusting a new certificate on each device.
- **No DHCP on the network:** the box's screen asks for an address.
- **Several Ethernet ports:** each with a link takes an address.
- **Moved to a different network:** the web UI offers to change the address.

## Owner guidance

Block the box's address from the internet at the router as well. This is part of the
design, not an extra. A live kernel compromise could change the box's own firewall until
the next reboot, but nothing on the box can change a router rule. See
[integrity](integrity.md).
