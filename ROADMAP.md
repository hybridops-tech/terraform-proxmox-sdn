# Roadmap

This roadmap tracks planned evolution of the `terraform-proxmox-sdn` module.

## 0.1.x line

Current line focuses on single-node Proxmox SDN with host-side orchestration.

### Delivered (0.1.0–0.1.2)

- Single-node, VLAN-backed SDN zone (L2 + optional host L3).
- dnsmasq DHCP support with `dns_domain` and `dns_lease`.
- Host-side gateway + SNAT + DHCP feature flags:
  - `enable_host_l3`
  - `enable_snat`
  - `enable_dhcp`
  - `uplink_interface`
- Examples:
  - `basic` (single VNet with DHCP)
  - `homelab-six-vlans` (mgmt/obs/dev/staging/prod/lab)
  - `no-dhcp` (L3 + NAT, no DHCP)
  - `multi-node` (single-node “cluster zone” plus scaffold)
- SDN auto-healing helper (optional) and systemd units.
- Documentation:
  - Module README (usage, constraints, inputs/outputs)
  - HOWTO: Proxmox SDN with Terraform
  - SDN operations runbook (deploy/validate/troubleshoot)

### Planned (remaining 0.1.x)

- Stronger validation for:
  - SDN IDs, VNet names, VLAN tags
  - DHCP range conflicts and invalid flag combinations
- Example hardening:
  - Ensure all examples pass `terraform init -backend=false` and `terraform validate` against released versions
  - Align comments and outputs for copy/paste consistency
- Additional reference patterns:
  - Small production-style layout (refined from `homelab-six-vlans`)
  - Minimal “L3 + NAT, no DHCP” pattern for sites with external DHCP

## 0.2.0

Cluster-aware multi-node SDN.

- First-class multi-node support for a shared SDN zone across multiple Proxmox nodes.
- Clear patterns for:
  - Single zone across a small cluster
  - Consistent VNet attachment across nodes
- Improved Proxmox API error handling and diagnostics (timeouts, auth failures, partial SDN state).
- Extended examples:
  - Promote `multi-node` from scaffold to supported example
  - Guidance for mixed automated + pre-existing SDN objects

## 0.3.0

Multi-zone and integration.

- Multiple SDN zones per deployment (e.g., `core`, `tenant`, `lab`).
- NetBox integration example using module outputs (IPAM export + inventory linkage).
- Terraform Cloud / Terraform Enterprise compatibility testing and docs.
- Advanced DHCP capabilities where safe to automate (reservations, additional options).

## 1.0.0

Stable, production-ready line.

- Stable input/output API with upgrade notes.
- Complete multi-node support with documented operational patterns.
- Automated test suite (unit + example validation).
- Hardened security guidance (least-privilege tokens, operational practices).
- CI/CD for releases:
  - Automated example validation
  - Registry publish flow
  - Documentation sync

## Future considerations

- IPv6 support.
- BGP/EVPN-backed SDN patterns.
- Dynamic DNS beyond dnsmasq.
- Observability hooks (Prometheus/Grafana-friendly metrics and logs).
- Backup/restore for SDN configuration.
- Integration with external IPAM/CMDB systems.
