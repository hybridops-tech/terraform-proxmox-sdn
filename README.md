# terraform-proxmox-sdn

[![Terraform Registry](https://img.shields.io/badge/terraform_registry-hybridops--studio%2Fsdn%2Fproxmox-623CE4.svg)](https://registry.terraform.io/modules/hybridops-studio/sdn/proxmox)

Terraform module for managing **Proxmox SDN** (Software-Defined Networking) with automated **DHCP via dnsmasq**.

It creates a VLAN-backed SDN zone, VNets, and subnets on **Proxmox VE 8.x**, and can configure dnsmasq on the Proxmox node to provide per-subnet DHCP pools. Suitable for both **homelabs** and small **production-style** environments.

The module can be used:

- As **standalone Terraform** in a small project or lab.
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
  source  = "hybridops-studio/proxmox-sdn/proxmox"
  version = "~> 0.1.1"

  # SDN zone ID must follow Proxmox SDN rules (<= 8 chars, no dashes)
  zone_name    = "hybzone"
  proxmox_node = var.proxmox_node
  proxmox_host = var.proxmox_host

  vnets = {
    vnetmgmt = {
      vlan_id     = 10
      description = "Management Network"

      subnets = {
        mgmt = {
          cidr             = "10.10.0.0/24"
          gateway          = "10.10.0.1"
          vnet             = "vnetmgmt"
          dhcp_enabled     = true
          dhcp_range_start = "10.10.0.100"
          dhcp_range_end   = "10.10.0.200"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }
  }

  dns_domain = "hybridops.local"
  dns_lease  = "24h"
}
```

Example variables:

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
platform/infra/terraform/live-v1/onprem/proxmox/core/00-foundation/network-sdn/
```

For a full Terragrunt-based walkthrough, see the how-to:

- [How-to: Proxmox SDN with Terraform](https://docs.hybridops.studio/howtos/network/proxmox-sdn-terraform/)

---

## Features

- Creates a VLAN-backed **SDN zone** on a Proxmox bridge.
- Manages **VNets** and **subnets** via a single `vnets` map.
- Assigns **gateway IPs** on VNet bridge interfaces.
- Generates `dnsmasq` **DHCP pools** per subnet and reloads the service.
- Designed to be **idempotent** and safe to re-apply.

Common environment layout:

- Tenant environments such as `mgmt`, `obs`, `dev`, `staging`, `prod`, `lab`.
- Per-subnet structure (for `/24`):
  - `.1` – gateway (VNet bridge)
  - `.2–.9` – infrastructure services
  - `.10–.99` – static IPs (IPAM / NetBox)
  - `.100–.200` – DHCP pool
  - `.201–.254` – reserved

---

## Requirements

- Proxmox VE **8.x** with SDN enabled.
- VLAN-aware bridge (for example `vmbr0`).
- `dnsmasq` installed on the Proxmox node.
- Terraform **>= 1.5.0**.
- Provider **bpg/proxmox >= 0.50.0**.
- SSH access from the runner to the Proxmox node for DHCP configuration.

---

## Inputs

### Core inputs

| Name           | Type   | Required | Description                                                         |
|----------------|--------|----------|---------------------------------------------------------------------|
| `zone_name`    | string | yes      | SDN zone ID (≤ 8 chars, lowercase, no dashes – Proxmox SDN rules). |
| `proxmox_node` | string | yes      | Proxmox node name (for example `pve` or `hybridhub`).               |
| `proxmox_host` | string | yes      | Proxmox host (IP or DNS) used to reach dnsmasq via SSH.             |
| `vnets`        | map    | yes      | Map of VNets and subnets (see structure below).                     |

### Optional inputs

| Name         | Type   | Default             | Description                        |
|--------------|--------|---------------------|------------------------------------|
| `dns_domain` | string | `"hybridops.local"` | DNS domain used in dnsmasq config. |
| `dns_lease`  | string | `"24h"`             | DHCP lease time.                   |

### VNet structure

Each VNet key must be a valid Proxmox SDN identifier (≤ 8 chars, no dashes).

```hcl
vnets = {
  vnetmgmt = {
    vlan_id     = number
    description = string
    subnets = {
      subnet_name = {
        cidr             = string
        gateway          = string
        vnet             = string   # usually matches the VNet key
        dhcp_enabled     = bool
        dhcp_range_start = string   # required if dhcp_enabled = true
        dhcp_range_end   = string   # required if dhcp_enabled = true
        dhcp_dns_server  = string
      }
    }
  }

  # additional VNets...
}
```

---

## Outputs

| Name       | Type   | Description                                                                                  |
|------------|--------|----------------------------------------------------------------------------------------------|
| `zone_name` | string | SDN zone name (Proxmox SDN zone ID).                                                         |
| `vnets`     | map    | Map of VNet keys to objects with `id`, `zone`, and `vlan_id`.                                |
| `subnets`   | map    | Map of subnet keys (`<vnet>-<subnet>`) to objects with CIDR, gateway, and DHCP configuration. |

### Example: inspecting outputs

After `terraform apply`, you can inspect outputs from any of the examples:

```bash
terraform output zone_name
terraform output vnets
terraform output subnets
```

Example (from the `basic` example):

```bash
terraform output subnets
```

```hcl
subnets = {
  "vnetmgmt-mgmt" = {
    id               = "hybzone-10.10.0.0-24"
    vnet             = "vnetmgmt"
    cidr             = "10.10.0.0/24"
    gateway          = "10.10.0.1"
    dhcp_enabled     = true
    dhcp_range_start = "10.10.0.100"
    dhcp_range_end   = "10.10.0.200"
    dhcp_dns_server  = "8.8.8.8"
  }
}
```

These can be consumed by other modules (for example VM modules that attach NICs to specific VNets).

---

## Design notes & Proxmox SDN constraints

### SDN IDs (zones and VNets)

Proxmox SDN enforces strict ID rules:

- Max length: 8 characters
- Lowercase, no spaces, no dashes
- Must be unique per SDN object type

This module assumes:

- `zone_name` is already a valid SDN ID (e.g. `hybzone`, `clust01`).
- VNet keys in `vnets` are also valid IDs (e.g. `vnetmgmt`, `vclst01m`).

If you violate these constraints, Proxmox will reject the API call and Terraform will fail with a 4xx/5xx error.

### DHCP behaviour

- DHCP is driven by a dnsmasq helper script on the Proxmox node.
- Only subnets with `dhcp_enabled = true` are rendered into `/etc/dnsmasq.d/sdn-dhcp.conf`.
- `terraform destroy` removes SDN objects but Proxmox may leave bridge interfaces in the kernel until networking is reloaded (see Known issues).

### Apply vs destroy

This module is designed for:

- Iterative `apply` to evolve SDN configuration safely.
- Occasional `destroy` in lab / demo environments only.

For production, prefer `apply`-driven changes over full destroy/recreate workflows.

---

## Examples

The GitHub repository includes ready-to-run examples under `examples/`:

| Example              | Description                                      |
|----------------------|--------------------------------------------------|
| `basic`              | Single VNet with DHCP (minimal config).          |
| `homelab-six-vlans`  | Six-VLAN homelab (mgmt/obs/dev/staging/prod/lab).|
| `no-dhcp`            | Static IP network without DHCP.                  |
| `multi-node`         | Planned multi-node pattern (current module is single-node). |

From an example directory:

```bash
cd examples/basic
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

The [How-to: Proxmox SDN with Terraform](https://docs.hybridops.studio/howtos/network/proxmox-sdn-terraform/) provides a higher-level narrative for both:

- A quick standalone Terraform project.
- A Terragrunt-based SDN stack inside the larger hybridops-platform repository.

---

## Multi-node roadmap

> **Status:** Design/roadmap – not yet supported in `v0.1.x`.  
> The goal is to reuse the same module to manage a **shared SDN zone** that spans multiple Proxmox nodes.

### Target design

The planned multi-node model looks like:

- **One SDN zone** (for example `clust01`) shared across all nodes.
- **Per-cluster VNets** with SDN-safe identifiers (≤ 8 chars, no dashes), for example:
  - `vclst01m` – cluster management
  - `vclst01d` – cluster data
- A single dnsmasq configuration that serves DHCP for all cluster VLANs.

In Terraform module terms, this would be driven by:

- `zone_name` – shared across all nodes.
- A future `nodes` input – list of node names (`["pve1", "pve2", "pve3"]`).
- A shared `vnets` map (same structure as in the single-node examples).

### Example scaffold (subject to change)

> **Do not use this in production yet** – this is a design sketch for a future `>= 0.2.0` release.

```hcl
module "sdn_cluster" {
  source  = "hybridops-studio/proxmox-sdn/proxmox"
  version = "~> 0.2.0"

  # Shared SDN zone across nodes (≤ 8 chars, no dashes)
  zone_name = "clust01"

  # Planned: list of nodes instead of a single node
  nodes = [
    "pve1",
    "pve2",
  ]

  vnets = {
    vclst01m = {
      vlan_id     = 200
      description = "Cluster management network"
      subnets = {
        mgmt = {
          cidr             = "10.200.0.0/24"
          gateway          = "10.200.0.1"
          vnet             = "vclst01m"
          dhcp_enabled     = true
          dhcp_range_start = "10.200.0.100"
          dhcp_range_end   = "10.200.0.150"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }

    # vclst01d, vclst01s, etc.
  }

  dns_domain = "hybridops.local"
  dns_lease  = "24h"

  proxmox_url      = var.proxmox_url
  proxmox_token    = var.proxmox_token
  proxmox_insecure = var.proxmox_insecure
}
```

A prototype of this layout is maintained under:

- `examples/multi-node/` in the module repository (experimental, subject to change).

---

## DHCP helper script

The module relies on a helper script to configure `dnsmasq` on the Proxmox node:

- Renders DHCP configuration for all `dhcp_enabled` subnets from the `vnets` map.
- Writes config to `/etc/dnsmasq.d/sdn-dhcp.conf` (default).
- Restarts or reloads `dnsmasq`.
- Triggers a Proxmox SDN reload to clear UI warnings.

Reference implementation:

- `scripts/setup-dhcp.sh`

This is invoked via a `null_resource` + `local-exec` provisioner that SSHs to `proxmox_host`.

---

## Known limitations

See:

- [`KNOWN-ISSUES-terraform-proxmox-sdn.md`](./KNOWN-ISSUES-terraform-proxmox-sdn.md) (in the GitHub repo).

Key points:

- SDN zone and VNet IDs must follow **Proxmox SDN naming rules** (≤ 8 chars, no dashes).
- After `destroy`, VNet bridge interfaces may persist until networking is reloaded (`ifreload -a` / `pvesh set /cluster/sdn`).
- `dnsmasq` is the only supported DHCP engine.
- Proxmox UI may show VNet status errors after apply (networks still work). See [`scripts/install-sdn-auto-healing.sh`](https://github.com/hybridops-studio/terraform-proxmox-sdn/blob/main/scripts/install-sdn-auto-healing.sh).

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

---

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