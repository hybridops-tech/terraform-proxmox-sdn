# terraform-proxmox-sdn

[![Terraform Registry](https://img.shields.io/badge/terraform_registry-hybridops--tech%2Fsdn%2Fproxmox-623CE4.svg)](https://registry.terraform.io/modules/hybridops-tech/sdn/proxmox)

Terraform module for managing **Proxmox SDN** (Software-Defined Networking) with optional **host L3**, **SNAT**, and **per-subnet DHCP via dnsmasq**.

It creates a VLAN-backed SDN zone, VNets, and subnets on **Proxmox VE 8.x** and can:

- Configure **gateway IPs** on VNet bridge interfaces (host L3).
- Add **SNAT / masquerade** rules per subnet.
- Provision **dnsmasq DHCP** pools per subnet.
- Emit a **NetBox-ready IPAM export payload** (prefixes + DHCP metadata).

> **Namespace Migration Notice**
>
> This module is now officially published under `hybridops-tech/sdn/proxmox`.
>
> The previous namespace `hybridops-studio/sdn/proxmox` remains available for
> compatibility but will not receive future releases.
>
> Please update your Terraform source reference.

Designed for **production-ready Proxmox platforms**, from advanced labs to full **production-style** environments, and usable:

- As **standalone Terraform** in a focused project, advanced lab, or production stack.
- As part of a **Terragrunt / monorepo stack** (for example, within the HybridOps.Studio `live-v1` layout).

---

## Usage

### Minimal example (Terraform Registry / standalone)

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.50.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_url
  api_token = var.proxmox_token
  insecure  = var.proxmox_insecure
}

module "sdn" {
  source  = "hybridops-tech/sdn/proxmox"
  version = "~> 0.1.4"

  # SDN zone ID must follow Proxmox SDN rules (<= 8 chars, no dashes)
  zone_name    = "hybzone"
  proxmox_node = var.proxmox_node
  proxmox_host = var.proxmox_host

  # Optional host L3 and SNAT
  enable_host_l3   = true
  enable_snat      = true
  uplink_interface = "vmbr0"

  # Optional DHCP (requires enable_host_l3 = true)
  enable_dhcp = true
  dns_domain  = "hybridops.local"
  dns_lease   = "24h"
  # Optional: force one host-side reconcile when recovering from drift
  # (gateway/NAT/DHCP) without changing topology inputs.
  # host_reconcile_nonce = "CHG-20260225-01"

  vnets = {
    vnetmgmt = {
      vlan_id     = 10
      description = "Management Network"

      subnets = {
        mgmt = {
          cidr    = "10.10.0.0/24"
          gateway = "10.10.0.1"

          # DHCP is opt-out at subnet level when enable_dhcp = true:
          # - omit dhcp_enabled to use module defaults (enabled with default ranges), or
          # - set dhcp_enabled = false to disable DHCP for this subnet.
          dhcp_enabled     = true
          dhcp_range_start = "10.10.0.100"
          dhcp_range_end   = "10.10.0.200"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }
  }
}
```

Example variables (API + node details):

```hcl
# Proxmox API configuration
proxmox_url      = "https://<PROXMOX-IP>:8006/api2/json"
proxmox_token    = "user@pam!tokenid=<YOUR-API-TOKEN-SECRET>"
proxmox_insecure = true

# Proxmox node configuration
proxmox_node = "<PROXMOX-NODE-NAME>"
proxmox_host = "<PROXMOX-IP>"
```

### GitHub source (monorepos / pinning tags)

For monorepos or Terragrunt-based stacks, you can pin a specific tag from GitHub instead of (or in addition to) the Registry:

```hcl
module "sdn" {
  source = "github.com/hybridops-tech/terraform-proxmox-sdn//."
  # Optionally pin a tag:
  # source = "github.com/hybridops-tech/terraform-proxmox-sdn//.?ref=v0.1.4"
}
```

In Terragrunt, this is typically wrapped via `terraform { source = "..." }` and `inputs = { ... }` in a stack directory such as:

```text
hybridops-platform/infra/terraform/live-v1/onprem/proxmox/core/00-foundation/network-sdn/
```

---

## Features

- Creates a VLAN-backed **SDN zone** on a Proxmox bridge.
- Manages **VNets** and **subnets** via a single `vnets` map.
- Optional **host L3**: assigns gateway IPs on VNet bridge interfaces.
- Optional **SNAT**: per-subnet masquerade to an uplink interface.
- Optional **dnsmasq DHCP**: per-subnet DHCP pools, driven from Terraform state.
- Exposes **NetBox IPAM export payload** via `output.ipam_prefixes`.
- Designed to be **idempotent** and safe to re-apply.

Typical reference layout (six VLANs):

- Environments: `mgmt`, `obs`, `dev`, `staging`, `prod`, `lab`.
- For `/24` subnets:
  - `.1` – gateway (VNet bridge).
  - `.2–.9` – infrastructure services.
  - `.10–.119` – static IPs (IPAM / NetBox).
  - `.120–.220` – DHCP pool.
  - `.221–.254` – reserved.

---

## Requirements

- Proxmox VE **8.x** with SDN enabled.
- VLAN-aware bridge (for example `vmbr0`).
- `dnsmasq` installed on the Proxmox node (if using DHCP).
- Terraform **>= 1.5.0**.
- Provider **bpg/proxmox >= 0.50.0**.
- SSH access from the runner to the Proxmox node for host-side configuration (L3 / SNAT / DHCP).

---

## Inputs

### Core inputs

| Name           | Type   | Required | Description |
|----------------|--------|----------|-------------|
| `zone_name`    | string | yes      | SDN zone ID (≤ 8 chars, lowercase, no dashes – Proxmox SDN rules). |
| `zone_bridge`  | string | no       | Proxmox bridge to attach the SDN zone to (default: `vmbr0`). |
| `proxmox_node` | string | yes      | Proxmox node name (for example `pve` or `hybridhub`). |
| `proxmox_host` | string | yes      | Proxmox host (IP or DNS) used over SSH for host-side scripts. |
| `vnets`        | map    | yes      | Map of VNets and subnets (see structure below). |

### Host L3 / SNAT / DHCP toggles

| Name               | Type   | Default | Description |
|--------------------|--------|---------|-------------|
| `enable_host_l3`   | bool   | `true`  | Configure VNet gateway IPs on the host (required for SNAT and DHCP). |
| `enable_snat`      | bool   | `true`  | Enable SNAT/masquerade for SDN subnets via `uplink_interface`. |
| `uplink_interface` | string | `vmbr0` | Uplink interface used for SNAT (typically the WAN/LAN bridge). |
| `enable_dhcp`      | bool   | `false` | Enable dnsmasq DHCP provisioning (requires `enable_host_l3 = true`). |
| `dns_domain`       | string | `hybridops.local` | DNS domain used in dnsmasq config. |
| `dns_lease`        | string | `24h`   | DHCP lease time (`<number><s|m|h|d>`, e.g. `24h`). |
| `host_reconcile_nonce` | string | `""` | Optional operator token to force host-side SDN reconciliation (gateway/NAT/DHCP) on the next apply, even when topology inputs are unchanged. |

> The module enforces that `enable_dhcp = true` requires `enable_host_l3 = true`, so dnsmasq can bind to VNet interfaces safely.

### Recovery / self-heal (host-side drift)

If host-side SDN state drifts (for example a `vnet*` bridge exists but the
expected gateway IP is missing) and topology inputs are unchanged, rerun
`terraform apply` with a one-time `host_reconcile_nonce` value to force the
host-side gateway/NAT/DHCP setup scripts to re-run:

```hcl
host_reconcile_nonce = "CHG-20260225-01"
```

This is the supported recovery path. Avoid changing unrelated settings (for
example `dns_lease`) just to trigger reconciliation.

### VNet structure

Each VNet key must be a valid Proxmox SDN identifier (≤ 8 chars, no dashes).

```hcl
vnets = {
  vnetmgmt = {
    vlan_id     = number
    description = string

    subnets = {
      subnet_name = {
        cidr    = string
        gateway = string

        # DHCP configuration:
        # - enable_dhcp must be true (module-level)
        # - dhcp_enabled is optional (subnet-level)
        #
        # Behaviour when enable_dhcp = true:
        # - dhcp_enabled omitted -> DHCP enabled using defaults (start/end/DNS), unless you override.
        # - dhcp_enabled = false -> DHCP disabled for that subnet.
        dhcp_enabled     = optional(bool)
        dhcp_range_start = optional(string)  # defaults to cidrhost(cidr, dhcp_default_start_host)
        dhcp_range_end   = optional(string)  # defaults to cidrhost(cidr, dhcp_default_end_host)
        dhcp_dns_server  = optional(string)  # defaults to dhcp_default_dns_server
      }
    }
  }

  # additional VNets...
}
```

---

## Outputs

| Name           | Type | Description |
|----------------|------|-------------|
| `zone_name`    | string | SDN zone name (Proxmox SDN zone ID). |
| `vnets`        | map    | Map of VNet keys to objects with `id`, `zone`, and `vlan_id`. |
| `subnets`      | map    | Map of subnet keys (`<vnet>-<subnet>`) to objects with CIDR, gateway, and DHCP metadata (effective values). |
| `ipam_prefixes`| list   | NetBox IPAM dataset derived from SDN inputs (prefixes + DHCP metadata). |

### Example: inspecting outputs

After `terraform apply`:

```bash
terraform output zone_name
terraform output vnets
terraform output subnets
terraform output -json ipam_prefixes
```

Example `ipam_prefixes` item (shape):

```hcl
{
  site         = "onprem-hybridhub"
  status       = "active"
  vlan_id      = 10
  role         = "management"
  prefix       = "10.10.0.0/24"
  gateway      = "10.10.0.1"
  dhcp_enabled = true
  dhcp_start   = "10.10.0.120"
  dhcp_end     = "10.10.0.220"
  description  = "Management network (static .2-.119; DHCP .120-.220)"
}
```

This output is designed to be consumed by downstream tooling (for example, NetBox seeders) without maintaining a separate IPAM CSV.

---

## DHCP behaviour

- DHCP is provided by **dnsmasq** on the Proxmox node, driven from the `vnets` map.
- DHCP is controlled at two levels:
  - Module-level: `enable_dhcp = true` enables DHCP orchestration.
  - Subnet-level: `dhcp_enabled` is an opt-out when `enable_dhcp = true`.
- When DHCP is enabled for a subnet and explicit ranges are not provided, the module derives defaults from:
  - `dhcp_default_start_host`
  - `dhcp_default_end_host`
  - `dhcp_default_dns_server`
- When `enable_dhcp = false`, no dnsmasq configuration is rendered and no DHCP systemd units are managed.
- When `enable_host_l3 = true` but `enable_dhcp = false`, you still get:
  - VNet bridge interfaces with gateway IPs.
  - Optional SNAT rules, so subnets can reach the internet with static IPs only.

---

## Known limitations

- SDN zone and VNet IDs must follow **Proxmox SDN naming rules** (≤ 8 chars, no dashes).
- After `destroy`, VNet bridge interfaces may persist until networking is reloaded (`ifreload -a` / `pvesh set /cluster/sdn`).
- `dnsmasq` is the only supported DHCP engine.
- Proxmox UI may show SDN/DHCP status warnings in some edge cases, even when traffic flows correctly.

---

## Architecture & docs (HybridOps.Studio)

This module implements the Proxmox SDN foundation used by HybridOps.Studio, including VLAN allocation and NetBox/IPAM integration via the `ipam_prefixes` output.

- [How-to: Proxmox SDN with Terraform](https://docs.hybridops.studio/howtos/network/proxmox-sdn-terraform/)
- [Network Architecture](https://docs.hybridops.studio/prerequisites/network-architecture/)
- [ADR-0101 – VLAN Allocation Strategy](https://docs.hybridops.studio/adr/ADR-0101-vlan-allocation-strategy/)
- [ADR-0102 – Proxmox as Core Router](https://docs.hybridops.studio/adr/ADR-0102-proxmox-intra-site-core-router/)
- [ADR-0104 – Static IP Allocation (Terraform IPAM)](https://docs.hybridops.studio/adr/ADR-0104-static-ip-allocation-terraform-ipam/)

---

## License

- Code: [MIT-0](https://spdx.org/licenses/MIT-0.html)  
- Documentation & diagrams: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

See the [HybridOps.Studio licensing overview](https://docs.hybridops.studio/briefings/legal/licensing/) for project-wide licence details.

---

## Contributing

Contributions are welcome via GitHub:

- [Repository](https://github.com/hybridops-tech/terraform-proxmox-sdn)

Before opening a PR:

- Run `terraform fmt`.
- Run `terraform validate`.
- Update `examples/` if inputs or usage change.
- Add a short entry to `CHANGELOG.md`.
