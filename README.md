# terraform-proxmox-sdn

Terraform module for managing Proxmox SDN (Software-Defined Networking) with automated DHCP configuration via dnsmasq. 

Designed for Proxmox VE 8.x environments requiring repeatable, version-controlled network segmentation.

---

## Features

- VLAN-based SDN zone management
- VNet and subnet provisioning
- Automated dnsmasq DHCP configuration
- Gateway address assignment on VNet bridges
- Idempotent operations

---

## Requirements

- Proxmox VE 8.x with SDN enabled
- Terraform 1.5+
- SSH access to Proxmox node for DHCP configuration

---

## Usage

### Basic Example

```hcl
module "sdn" {
  source = "github.com/hybridops-studio/terraform-proxmox-sdn"

  zone_name    = "datacenter-zone"
  proxmox_node = "pve"
  proxmox_host = "192.168.1.10"

  vnets = {
    vnetmgmt = {
      vlan_id     = 10
      description = "Management Network"

      subnets = {
        mgmt = {
          cidr             = "10.10.0.0/24"
          gateway          = "10.10.0.1"
          dhcp_enabled     = true
          dhcp_range_start = "10.10.0.100"
          dhcp_range_end   = "10.10.0.200"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }
  }

  proxmox_url      = var.proxmox_url
  proxmox_token    = var.proxmox_token
  proxmox_insecure = true
}
```

### Multi-VLAN Environment

```hcl
module "sdn" {
  source = "github.com/hybridops-studio/terraform-proxmox-sdn"

  zone_name    = "production-zone"
  proxmox_node = "pve"
  proxmox_host = "192.168.1.10"

  vnets = {
    vnetmgmt = {
      vlan_id     = 10
      description = "Management"
      subnets = {
        mgmt = {
          cidr             = "10.10.0.0/24"
          gateway          = "10.10.0.1"
          dhcp_enabled     = true
          dhcp_range_start = "10.10.0.100"
          dhcp_range_end   = "10.10.0.200"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }

    vnetdev = {
      vlan_id     = 20
      description = "Development"
      subnets = {
        dev = {
          cidr             = "10.20.0.0/24"
          gateway          = "10.20.0.1"
          dhcp_enabled     = true
          dhcp_range_start = "10.20.0.100"
          dhcp_range_end   = "10.20.0.200"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }

    vnetprod = {
      vlan_id     = 40
      description = "Production"
      subnets = {
        prod = {
          cidr             = "10.40.0.0/24"
          gateway          = "10.40.0.1"
          dhcp_enabled     = true
          dhcp_range_start = "10.40.0.100"
          dhcp_range_end   = "10.40.0.200"
          dhcp_dns_server  = "8.8.8.8"
        }
      }
    }
  }

  proxmox_url      = var.proxmox_url
  proxmox_token    = var.proxmox_token
  proxmox_insecure = true
}
```

---

## Inputs

| Name              | Type   | Required | Description                                    |
|-------------------|--------|----------|------------------------------------------------|
| `zone_name`       | string | yes      | SDN zone identifier                            |
| `proxmox_node`    | string | yes      | Proxmox node name                              |
| `proxmox_host`    | string | yes      | Proxmox host IP for SSH access                 |
| `proxmox_url`     | string | yes      | Proxmox API endpoint                           |
| `proxmox_token`   | string | yes      | Proxmox API token                              |
| `proxmox_insecure`| bool   | no       | Skip TLS verification (default: false)         |
| `vnets`           | map    | yes      | VNet definitions with subnets and DHCP config  |

### VNet Structure

```hcl
vnets = {
  vnet_name = {
    vlan_id     = number
    description = string
    subnets = {
      subnet_name = {
        cidr              = string
        gateway           = string
        dhcp_enabled      = bool
        dhcp_range_start  = string  # Required if dhcp_enabled = true
        dhcp_range_end    = string  # Required if dhcp_enabled = true
        dhcp_dns_server   = string  # Optional
      }
    }
  }
}
```

---

## Outputs

| Name        | Description                        |
|-------------|------------------------------------|
| `zone_name` | Created SDN zone identifier        |
| `vnets`     | Map of VNet IDs and configurations |
| `subnets`   | Map of subnet configurations       |

---

## Examples

Complete examples available in `examples/`:

- `basic/` - Single VNet with DHCP
- `homelab-six-vlans/` - Six-VLAN homelab setup
- `no-dhcp/` - Static IP configuration
- `multi-node/` - Multi-node cluster (planned)

---

## DHCP Configuration

The module executes `scripts/setup-dhcp.sh` via SSH to configure dnsmasq on the Proxmox node.  The script:

1. Installs dnsmasq if not present
2. Configures IP addresses on VNet bridge interfaces
3. Generates DHCP ranges for enabled subnets
4. Reloads SDN configuration

Manual DHCP configuration can be used by omitting the `null_resource. dhcp_setup` block.

---

## Limitations

- Single-node configuration (multi-node support planned)
- Requires SSH access with root privileges
- DHCP via dnsmasq only (ISC DHCP not supported)

---

## License

MIT-0 (MIT No Attribution)

---

## Contributing

Contributions welcome.  Submit issues or pull requests via GitHub.

Repository: https://github.com/hybridops-studio/terraform-proxmox-sdn