# Roadmap

This roadmap tracks planned evolution of the `terraform-proxmox-sdn` module.

## 0.1.x line

The stable 0.1.x line focuses on single-node Proxmox SDN with host-side
orchestration.

### Delivered (0.1.0-0.1.6)

- Single-node, VLAN-backed SDN zone (L2 + optional host L3).
- dnsmasq DHCP support with `dns_domain` and `dns_lease`.
- Host-side gateway + SNAT + DHCP feature flags:
  - `enable_host_l3`
  - `enable_snat`
  - `enable_dhcp`
  - `uplink_interface`
- Examples:
  - `basic` (single VNet with DHCP)
  - `homelab-six-vlans` (mgmt/obs/dev/staging/prod/validation)
  - `no-dhcp` (L3 + NAT, no DHCP)
  - `multi-node` (single-node “cluster zone” plus scaffold)
- SDN auto-healing helper (optional) and systemd units.
- Managed host static routes for upstream and cloud-prefix handoff.
- Documentation:
  - Module README (usage, constraints, inputs/outputs)
  - HOWTO: Proxmox SDN with Terraform
  - SDN operations runbook (deploy/validate/troubleshoot)

## 0.2.x line

The 0.2.x line adds cluster-aware SDN membership and an API-only operating
mode while preserving the 0.1.x single-node input path.

### Delivered in 0.2.0

- Optional cluster-wide node membership through `proxmox_nodes`.
- API-only edge-routed deployments that do not require Proxmox host login.
- Plan-time validation for SDN zone IDs, VNet IDs, and VLAN IDs.
- Native Terraform tests for operating modes, node membership, and validation.
- CI validation for the root module, every example, and host-side shell scripts.
- Supported `multi-node` and `api-only-edge-routed` examples.
- Brownfield ownership, import, access, and local validation guidance.
- Current `proxmox_sdn_*` resource names with state-preserving moved blocks.
- Plan-time validation for incompatible host flags, duplicate routes, VNet
  aliases, and active DHCP ranges.
- Optional host recovery watcher lifecycle.

### Planned for later 0.2.x

- Improved Proxmox API diagnostics for timeouts, authentication failures, and
  partial SDN state.
- Additional live multi-node apply and destroy coverage.
- Additional IPAM output contract coverage.
- Small production-style and external-DHCP reference patterns.

## 0.3.0

Multi-zone and integration.

- Multiple SDN zones per deployment (for example `core`, `tenant`, `validation`).
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
