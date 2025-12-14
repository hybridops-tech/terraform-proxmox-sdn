# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Multi-node cluster support (single shared SDN zone across nodes)
- Enhanced error handling and validation around SDN IDs and DHCP
- NetBox integration example

## [0.1.1] - 2025-12-14

### Added
- Self-healing system for VNet status management via `install-sdn-auto-healing.sh`
- Systemd-based monitoring and automatic correction of Proxmox UI VNet status display
- Documentation reference to self-healing script in known limitations

### Fixed
- Corrected `examples/basic` SDN configuration to match the current module inputs
- Updated all example VNets and zone IDs to comply with Proxmox SDN ID rules (≤ 8 chars, no dashes)
- Ensured `no-dhcp` example correctly disables DHCP while still provisioning SDN objects

### Changed
- Improved README usage examples and examples documentation for clarity and consistency
- Documented known SDN behaviours and workarounds (e.g.VNet interface persistence after destroy)

## [0.1.0] - 2025-12-13

### Added
- Initial release
- VLAN-based SDN zone management
- VNet and subnet provisioning
- Automated dnsmasq DHCP configuration
- Gateway IP assignment on VNet bridges
- Examples: `basic`, `homelab-six-vlans`, `no-dhcp`, `multi-node` (single-node usage today, multi-node planned)
- Optional DHCP cleanup on destroy via `cleanup-dhcp.sh`
