# Examples

Each example demonstrates a specific use case for the `terraform-proxmox-sdn` module.

## Available Examples

| Example             | Description                                       |
|---------------------|---------------------------------------------------|
| `basic`             | Single VNet with DHCP – minimal configuration     |
| `homelab-six-vlans` | Six-VLAN homelab (mgmt/obs/dev/staging/prod/lab)  |
| `no-dhcp`           | Static IP network without DHCP                    |
| `multi-node`        | Multi-node cluster setup (planned feature)        |

---

## Usage

1. Navigate to an example directory, for example:

   ```bash
   cd examples/basic
   ```

2. Copy the example variables file:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit `terraform.tfvars` with your Proxmox credentials and desired settings.

4. Initialize and apply Terraform:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

---

## Required Variables

All examples expect at least the following variables:

```hcl
proxmox_url      = "https://PROXMOX-IP:8006/api2/json"
proxmox_token    = "USER@REALM!terraform=UUID"
proxmox_insecure = true
proxmox_node     = "pve"
proxmox_host     = "PROXMOX-IP"
```

> **Note:** `proxmox_insecure` should be set to `false` if your Proxmox instance has a valid TLS certificate.

---

## Creating an API Token

1. Log in to the Proxmox web interface.
2. Navigate to **Datacenter → Permissions → API Tokens**.
3. Click **Add** and create a token for the desired user.
4. Copy both the **token ID** and **secret**.
5. Combine them in the format expected by the examples, for example:

   ```text
   root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```

This string is then assigned to `proxmox_token` in `terraform.tfvars`.

---

## Example: `examples/basic/terraform.tfvars.example`

```hcl
# Proxmox API configuration
proxmox_url      = "https://192.168.1.10:8006/api2/json"
proxmox_token    = "root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
proxmox_insecure = true

# Proxmox node configuration
proxmox_node = "pve"
proxmox_host = "192.168.1.10"
```

You can use this as a starting point and adjust IPs, node names, and credentials to match your environment.