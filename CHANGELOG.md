# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `host_reconcile_nonce` input to explicitly force host-side SDN reconciliation
  (gateway/NAT/DHCP) when topology inputs are unchanged but host state drifted.

## [0.1.4] - 2026-02-25

### Added
- `host_reconcile_nonce` input to explicitly force host-side SDN reconciliation
  (gateway/NAT/DHCP) during same-input recovery runs (for example when host
  gateway IPs drift but SDN topology inputs are unchanged).

## [0.1.3] - 2026-02-24

### Fixed
- Re-run host gateway, SNAT, and DHCP setup after SDN reload input changes
  (zone/VNet expansions/contractions) so existing VNet interfaces do not lose
  gateway configuration during topology updates.

### Added
- `ipam_prefixes` output for NetBox/IPAM dataset export from SDN inputs.

### Changed
- DHCP/subnet outputs now report effective values (including module defaults)
  for downstream consumers.

## [0.1.2] - 2025-12-29

### Added
- Host-level feature flags for services on the Proxmox node:
  - `enable_host_l3` – configure gateways on VNet interfaces.
  - `enable_snat` – enable SNAT for SDN subnets via the chosen uplink.
  - `enable_dhcp` – toggle dnsmasq-based DHCP across eligible subnets.
- Flexible DHCP semantics at subnet level:
  - DHCP is enabled implicitly when `enable_dhcp = true` and both
    `dhcp_range_start` and `dhcp_range_end` are set, even if `dhcp_enabled`
    is omitted.
  - `dhcp_enabled = true` forces DHCP on for that subnet.
  - `dhcp_enabled = false` forces DHCP off for that subnet, even when
    ranges are defined (ranges become documentation only).
- Validation guardrails:
  - `enable_dhcp = true` requires `enable_host_l3 = true` so dnsmasq can bind
    to the VNet interfaces safely.
- IPAM export payload output:
  - Added `ipam_prefixes` output to provide a NetBox-ready dataset derived from
    SDN inputs (prefixes + DHCP metadata).
  - Added IPAM metadata inputs:
    - `ipam_site`, `ipam_status` – stamp site/status onto `ipam_prefixes`.
    - `static_last_host` – used for description text when generating the
      NetBox IPAM payload.
    - `dhcp_default_dns_server`, `dhcp_default_start_host`,
      `dhcp_default_end_host` – default DHCP values when not set per subnet.

### Changed
- SDN orchestration:
  - Introduced `null_resource.sdn_reload` to apply `/cluster/sdn`, wait for
    all `vnet*` interfaces to appear with retries, and emit diagnostics if
    interfaces fail to materialise.
  - Routed gateway, NAT, and DHCP setup through `sdn_reload` to avoid race
    conditions between SDN apply and host-level configuration.
- Cleanup behaviour:
  - Separated `gateway_cleanup`, `nat_cleanup`, and `dhcp_cleanup` to use
    stable triggers (zone name, host, VNet hash), improving destroy ordering
    and idempotency.
- Outputs:
  - `subnets[*].dhcp_enabled` now reports the effective DHCP state, derived
    from module-level flags and per-subnet fields.
  - `subnets[*].dhcp_range_start`, `subnets[*].dhcp_range_end`, and
    `subnets[*].dhcp_dns_server` now report effective values (including module
    defaults) when DHCP is enabled.
- Examples updated to use the new flags and semantics:
  - `basic` – minimal VNet with implicit DHCP (ranges only).
  - `homelab-six-vlans` – six-VLAN reference layout (mgmt/obs/dev/staging/prod/lab)
    with L3, SNAT, and per-VNet DHCP.
  - `no-dhcp` – static-only network with L3 + SNAT enabled and no DHCP.
  - `multi-node` – single-node “cluster zone” layout plus a commented scaffold
    for future multi-node support.
- Documentation:
  - Module README updated to describe `enable_host_l3`, `enable_snat`,
    `enable_dhcp`, and implicit vs explicit DHCP behaviour.
  - SDN operations documentation in HybridOps.Studio platform docs aligned with
    the 0.1.2 behaviour and examples.
  - Clarified that the SDN auto-healing helper is optional and not required for
    correct routing, NAT, or DHCP.

### Fixed
- Ensured no-DHCP scenarios still:
  - Attach the correct gateway IPs to VNet interfaces.
  - Configure NAT rules for outbound connectivity.
  - Avoid creating any dnsmasq units or DHCP listeners.
- Reduced residual SDN artefacts on destroy by:
  - Cleaning dnsmasq config, leases, and unit files before re-applying
    `/cluster/sdn`.
  - Re-running SDN apply via the finalizer to minimise stale SDN warnings
    in the Proxmox UI.
- Verified all examples under `examples/` pass:
  - `terraform init -backend=false`
  - `terraform validate`
  when executed from within the module repository.

## [0.1.1] - 2025-12-26

### Added
- dnsmasq-based DHCP helper for Proxmox SDN subnets, including support for
  `dns_domain` and `dns_lease` inputs.
- SDN auto-healing script and systemd units to keep Proxmox SDN status aligned
  with the running configuration and clear stale warnings in the UI.
- Updated examples:
  - `basic` – single VNet with DHCP and standard `.120–.220` pool.
  - `homelab-six-vlans` – six-VLAN reference layout (mgmt/obs/dev/staging/prod/lab).
  - `no-dhcp` – static-only network with DHCP disabled.
  - `multi-node` – single-node implementation plus commented scaffold for
    future multi-node support.
- Roadmap and documentation updates describing the 0.1.x line and planned
  multi-node evolution.

### Changed
- Standardised VNet and subnet input structure:
  - Subnets now use `dhcp_enabled`, `dhcp_range_start`, `dhcp_range_end`,
    and `dhcp_dns_server` fields only (no `vnet` field required inside the
    subnet map).
  - DHCP ranges in examples follow the reserved layout (`.120–.220`) to match
    the documented IP allocation strategy.
- Refined README usage examples to use `dns_domain` / `dns_lease` and to
  reference the module via the Terraform Registry for external consumers.

### Fixed
- Improved SDN destroy behaviour by cleaning up dnsmasq units, leases, and
  pidfiles, and re-applying `/cluster/sdn` to reduce lingering SDN warnings
  in the Proxmox UI.
- Ensured all examples pass `terraform init -backend=false` and
  `terraform validate` when run from the module repository.

## [0.1.0] - 2025-12-06

### Added
- Initial Proxmox SDN Terraform module for single-node, VLAN-backed SDN zones.
- Support for creating:
  - A VLAN-backed SDN zone on a Proxmox bridge.
  - VNets and subnets via a single `vnets` map input.
- Baseline example for a single VNet with a `/24` subnet and gateway on the
  VNet bridge.
- Documentation for SDN ID constraints and basic network layout.
