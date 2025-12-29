
# terraform-proxmox-sdn

[![Terraform Registry](https://img.shields.io/badge/terraform_registry-hybridops--studio%2Fsdn%2Fproxmox-623CE4.svg)](https://registry.terraform.io/modules/hybridops-studio/sdn/proxmox)

Terraform module for managing **Proxmox SDN** (Software-Defined Networking) with optional **host L3**, **SNAT**, and **per-subnet DHCP via dnsmasq**.

It creates a VLAN-backed SDN zone, VNets, and subnets on **Proxmox VE 8.x** and can:

- Configure **gateway IPs** on VNet bridge interfaces (host L3).
- Add **SNAT / masquerade** rules per subnet.
- Provision **dnsmasq DHCP** pools per subnet.

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
  source  = "hybridops-studio/sdn/proxmox"
  version = "~> 0.1.1"

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

  vnets = {
    vnetmgmt = {
      vlan_id     = 10
      description = "Management Network"

      subnets = {
        mgmt = {
          cidr    = "10.10.0.0/24"
          gateway = "10.10.0.1"

          # DHCP can be opted in either by:
          # - dhcp_enabled = true  + ranges, or
          # - omitting dhcp_enabled and just setting ranges.
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
  source = "github.com/hybridops-studio/terraform-proxmox-sdn//."
  # Optionally pin a tag:
  # source = "github.com/hybridops-studio/terraform-proxmox-sdn//.?ref=v0.1.1"
}
```

In Terragrunt, this is typically wrapped via `terraform { source = "..." }` and `inputs = { ... }` in a stack directory such as:

```text
hybridops-platform/infra/terraform/live-v1/onprem/proxmox/core/00-foundation/network-sdn/
```

For a full Terragrunt-based walkthrough, see the how-to:

- How-to: Proxmox SDN with Terraform (docs URL TBD)

---

## Features

- Creates a VLAN-backed **SDN zone** on a Proxmox bridge.
- Manages **VNets** and **subnets** via a single `vnets` map.
- Optional **host L3**: assigns gateway IPs on VNet bridge interfaces.
- Optional **SNAT**: per-subnet masquerade to an uplink interface.
- Optional **dnsmasq DHCP**: per-subnet DHCP pools, driven from Terraform state.
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

| Name           | Type   | Required | Description                                                                 |
|----------------|--------|----------|-----------------------------------------------------------------------------|
| `zone_name`    | string | yes      | SDN zone ID (≤ 8 chars, lowercase, no dashes – Proxmox SDN rules).         |
| `zone_bridge`  | string | no       | Proxmox bridge to attach the SDN zone to (default: `vmbr0`).               |
| `proxmox_node` | string | yes      | Proxmox node name (for example `pve` or `hybridhub`).                       |
| `proxmox_host` | string | yes      | Proxmox host (IP or DNS) used over SSH for L3/SNAT/DHCP scripts.           |
| `vnets`        | map    | yes      | Map of VNets and subnets (see structure below).                             |

### Host L3 / SNAT / DHCP toggles

| Name               | Type   | Default           | Description                                                                 |
|--------------------|--------|-------------------|-----------------------------------------------------------------------------|
| `enable_host_l3`   | bool   | `true`            | Configure VNet gateway IPs on the host (required for SNAT and DHCP).       |
| `enable_snat`      | bool   | `true`            | Enable SNAT/masquerade for SDN subnets via `uplink_interface`.             |
| `uplink_interface` | string | `"vmbr0"`         | Uplink interface used for SNAT (typically the WAN/LAN bridge).             |
| `enable_dhcp`      | bool   | `false`           | Enable dnsmasq DHCP provisioning (requires `enable_host_l3 = true`).       |
| `dns_domain`       | string | `"hybridops.local"` | DNS domain used in dnsmasq config.                                       |
| `dns_lease`        | string | `"24h"`           | DHCP lease time (`<number><s|m|h|d>`, e.g. `24h`).                          |

> The module enforces that `enable_dhcp = true` requires `enable_host_l3 = true`, so dnsmasq can bind to VNet interfaces safely.

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

        # DHCP is optional and can be expressed in two ways:
        # 1) Explicit flag + ranges:
        #    dhcp_enabled     = true
        #    dhcp_range_start = "10.10.0.120"
        #    dhcp_range_end   = "10.10.0.220"
        # 2) Implicit (no flag, just ranges):
        #    dhcp_range_start = "10.10.0.120"
        #    dhcp_range_end   = "10.10.0.220"
        #
        # If no flag and no ranges are provided, the subnet is L3-only (no DHCP).
        dhcp_enabled     = optional(bool)
        dhcp_range_start = optional(string)
        dhcp_range_end   = optional(string)
        dhcp_dns_server  = optional(string)
      }
    }
  }

  # additional VNets...
}
```

Validation rules:

- If `dhcp_enabled = true`, both `dhcp_range_start` and `dhcp_range_end` must be set for that subnet.
- If `enable_dhcp = false`, DHCP configuration is ignored, but host L3/SNAT can still be enabled.

---

## Outputs

| Name        | Type   | Description                                                                 |
|-------------|--------|-----------------------------------------------------------------------------|
| `zone_name` | string | SDN zone name (Proxmox SDN zone ID).                                       |
| `vnets`     | map    | Map of VNet keys to objects with `id`, `zone`, and `vlan_id`.              |
| `subnets`   | map    | Map of subnet keys (`<vnet>-<subnet>`) to objects with CIDR, gateway, and DHCP metadata. |

### Example: inspecting outputs

After `terraform apply`:

```bash
terraform output zone_name
terraform output vnets
terraform output subnets
```

Example `subnets` output snippet:

```hcl
subnets = {
  "vnetmgmt-mgmt" = {
    id               = "..."
    vnet             = "vnetmgmt"
    cidr             = "10.10.0.0/24"
    gateway          = "10.10.0.1"
    dhcp_enabled     = true
    dhcp_range_start = "10.10.0.120"
    dhcp_range_end   = "10.10.0.220"
    dhcp_dns_server  = "8.8.8.8"
  }
}
```

Other modules (for example VM modules) can consume these to attach NICs or derive IP ranges.

---

## DHCP behaviour

- DHCP is provided by **dnsmasq** on the Proxmox node, driven from the `vnets` map.
- Only subnets that appear in the effective **DHCP set** are rendered:
  - `dhcp_enabled = true` → always included (ranges required).
  - `dhcp_enabled` omitted → included only if both `dhcp_range_start` and `dhcp_range_end` are set.
- When `enable_dhcp = false`, no dnsmasq configuration is rendered and no DHCP systemd units are managed.
- When `enable_host_l3 = true` but `enable_dhcp = false`, you still get:
  - VNet bridge interfaces with gateway IPs.
  - Optional SNAT rules, so subnets can reach the internet with static IPs only.

This makes it easy to:

- Start with **L3 + SNAT only** (no DHCP).
- Later turn on `enable_dhcp = true` and add DHCP ranges to selected subnets.

---

## Examples

The GitHub repository can include ready-to-run examples under `examples/`:

| Example              | Description                                      |
|----------------------|--------------------------------------------------|
| `basic`              | Single VNet with DHCP (minimal config).         |
| `homelab-six-vlans`  | Six‑VLAN reference design (mgmt/obs/dev/staging/prod/lab).|
| `no-dhcp`            | Static IP network without DHCP.                  |
| `multi-node`         | Planned multi-node pattern (current module is single-node). |

From an example directory:

```bash
cd examples/basic
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

---

## Known limitations

- SDN zone and VNet IDs must follow **Proxmox SDN naming rules** (≤ 8 chars, no dashes).
- After `destroy`, VNet bridge interfaces may persist until networking is reloaded (`ifreload -a` / `pvesh set /cluster/sdn`).
- `dnsmasq` is the only supported DHCP engine.
- Proxmox UI may show SDN/DHCP status warnings in some edge cases, even when traffic flows correctly. A helper script such as `install-sdn-auto-healing.sh` can be used to auto-heal/quiet known Proxmox SDN quirks.

---

## Architecture & docs (optional context)

This module underpins the HybridOps.Studio Proxmox SDN design, but it is **not** tied to that project – it can be used in any Terraform / Terragrunt codebase.

If you want the broader architecture and narrative:

- [How-to: Proxmox SDN with Terraform](https://docs.hybridops.studio/howtos/network/proxmox-sdn-terraform/)
- [Network Architecture](https://docs.hybridops.studio/prerequisites/network-architecture/)
- [ADR-0101 – VLAN Allocation Strategy](https://docs.hybridops.studio/adr/ADR-0101-vlan-allocation-strategy/)
- [ADR-0102 – Proxmox as Core Router](https://docs.hybridops.studio/adr/ADR-0102-proxmox-intra-site-core-router/)
- [ADR-0104 – Static IP Allocation (Terraform IPAM)](https://docs.hybridops.studio/adr/ADR-0104-static-ip-allocation-terraform-ipam/)

These links are optional context for Registry users but provide a full picture when browsing on GitHub or the docs site.


## License

Code: **MIT-0 (MIT No Attribution)**

---

## Contributing

Contributions are welcome via GitHub:

- Repository: https://github.com/hybridops-studio/terraform-proxmox-sdn

Before opening a PR:

- Run `terraform fmt`.
- Run `terraform validate`.
- Update `examples/` if the inputs or usage change.
- Add a short entry to `CHANGELOG.md`.
