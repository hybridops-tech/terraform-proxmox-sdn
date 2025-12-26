# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2025-12-26

### Added
- dnsmasq-based DHCP helper for Proxmox SDN subnets, including support for `dns_domain` and `dns_lease` inputs.
- SDN auto-healing script and systemd units to keep Proxmox SDN status aligned with the running configuration and clear stale warnings in the UI.
- Updated examples:
  - `basic` – single VNet with DHCP and standard `.120–.220` pool.
  - `homelab-six-vlans` – six-VLAN homelab layout (mgmt/obs/dev/staging/prod/lab).
  - `no-dhcp` – static-only network with DHCP disabled.
  - `multi-node` – single-node implementation plus commented scaffold for future multi-node support.
- Roadmap and documentation updates describing the 0.1.x line and planned multi-node evolution.

### Changed
- Standardised VNet and subnet input structure:
  - Subnets now use `dhcp_enabled`, `dhcp_range_start`, `dhcp_range_end`, and `dhcp_dns_server` fields only (no `vnet` field required inside the subnet map).
  - DHCP ranges in examples now follow the reserved layout (`.120–.220`) to match the documented IP allocation strategy.
- Refined README usage examples to use `dns_domain` / `dns_lease` and to reference the module via the Terraform Registry for external consumers.

### Fixed
- Improved SDN destroy behaviour by cleaning up dnsmasq units, leases, and pidfiles, and re-applying `/cluster/sdn` to reduce lingering SDN warnings in the Proxmox UI.
- Ensured all examples pass `terraform init -backend=false` and `terraform validate` when run from the module repository.

## [0.1.0] - 2025-12-06

### Added
- Initial Proxmox SDN Terraform module for single-node, VLAN-backed SDN zones.
- Support for creating:
  - A VLAN-backed SDN zone on a Proxmox bridge.
  - VNets and subnets via a single `vnets` map input.
- Baseline examples for a single VNet with a `/24` subnet and gateway on the VNet bridge.
- Documentation for SDN ID constraints and basic network layout.
