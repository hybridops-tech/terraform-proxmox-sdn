# Roadmap

## 0.1.x line (current – single-node SDN)

### Completed in 0.1.0–0.1.2
- Single-node, VLAN-backed SDN zone on a Proxmox bridge (L2 + L3).
- dnsmasq-based DHCP helper with support for `dns_domain` and `dns_lease`.
- NAT and gateway setup for SDN subnets via `enable_host_l3`, `enable_snat`, and `uplink_interface`.
- Example layouts:
  - `basic` – single VNet with DHCP.
  - `homelab-six-vlans` – six-VLAN layout (mgmt/obs/dev/staging/prod/lab).
  - `no-dhcp` – static-only network with L3 + NAT and no DHCP.
  - `multi-node` – single-node “cluster zone” example plus scaffold for future multi-node support.
- SDN auto-healing helper and systemd units to normalise SDN state on the Proxmox node.
- Documentation set:
  - Module README (usage, constraints, examples).
  - HOWTO: Proxmox SDN with Terraform.
  - SDN operations runbook (deploy, validate, troubleshoot).

### Planned for remaining 0.1.x
- Stronger input validation and error handling for:
  - SDN IDs, VNet names, and VLAN tags.
  - Conflicting DHCP ranges and invalid combinations of `enable_host_l3` / `enable_dhcp`.
- Example hardening:
  - Ensure all examples pass `terraform init -backend=false` and `terraform validate` against the released module.
  - Align comments and outputs across examples for easier copy/paste.
- Additional “reference patterns”:
  - Small production-style layout (refined from `homelab-six-vlans`).
  - Minimal “L3 + NAT, no DHCP” pattern for sites with external DHCP.

---

## 0.2.0 – Multi-node & cluster-aware SDN

- First-class multi-node support for a shared SDN zone across multiple Proxmox nodes.
- Clear patterns for:
  - Single zone across a small cluster.
  - How to attach VNets consistently on multiple nodes.
- Improved Proxmox API error handling and diagnostics (timeouts, auth failures, partial SDN state).
- Extended examples:
  - Multi-node SDN example promoted from scaffold to fully supported pattern.
  - Guidance on mixing automated SDN with existing/manual SDN objects.

---

## 0.3.0 – Multi-zone and integration

- Multiple SDN zones per deployment (e.g. “core”, “tenant”, “lab”).
- NetBox integration example using module outputs (IPAM + inventory).
- Terraform Cloud / Terraform Enterprise compatibility testing and documentation.
- Advanced DHCP capabilities (reservations / additional options) where they can be safely automated.

---

## 1.0.0 – Stable, production-ready line

- Stable module input/output API with documented upgrade notes.
- Complete multi-node, production-ready support with documented patterns.
- Comprehensive automated test suite (unit + example validation).
- Hardened security posture (token usage, least-privilege guidance, and docs).
- CI/CD pipeline for releases, including:
  - Automatic example validation.
  - Registry publishing and documentation sync.

---

## Future considerations

- IPv6 support.
- BGP/EVPN-backed SDN zones.
- Dynamic DNS integration beyond dnsmasq.
- Network observability hooks (Prometheus / Grafana-friendly metrics and logs).
- Automated backup and restore for SDN configuration.
- Deeper integration with external IPAM / CMDB systems.