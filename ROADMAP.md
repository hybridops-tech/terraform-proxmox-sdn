# Roadmap

## 0.1.x line (current)

### Completed in 0.1.1
- Self-healing SDN VNet status handling (systemd-based auto-fix)
- Automated SDN status correction after configuration changes
- Improved documentation and examples for single-node SDN with DHCP

### Planned for 0.1.x
- Stronger validation and error handling for SDN IDs and VNet names
- Additional example configurations (homelab and small production patterns)
- Improved DHCP configuration validation and guardrails

## 0.2.0

- Multi-node cluster support (shared SDN zone across multiple nodes)
- Improved Proxmox API error handling and diagnostics
- Optional SDN controller integration
- Enhanced validation for zone and VNet naming conventions

## 0.3.0

- Multiple SDN zones per deployment
- BGP/EVPN-backed SDN zone support
- Advanced DHCP capabilities (reservations, additional options)
- Terraform Cloud / Terraform Enterprise compatibility testing
- NetBox integration example using module outputs

## 1.0.0

- Stable module API
- Complete multi-node, production-ready support
- Comprehensive automated test suite
- Hardening and security review
- Full CI/CD pipeline for releases

## Future considerations

- IPv6 support
- Dynamic DNS integration beyond dnsmasq
- Network observability hooks (Prometheus / Grafana integration)
- Automated backup and restore for SDN configuration
- Deeper integration with external IPAM systems
