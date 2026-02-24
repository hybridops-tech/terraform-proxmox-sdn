# Examples

Each directory under `examples/` demonstrates a specific use case for the `terraform-proxmox-sdn` module.

## Available examples

| Example | Description |
|---|---|
| `basic` | Single VNet with DHCP (minimal configuration). |
| `homelab-six-vlans` | Six VLANs (mgmt/obs/dev/staging/prod/lab). |
| `no-dhcp` | Static IP networking without DHCP. |
| `multi-node` | Multi-node pattern (planned). |

## Run an example

From the repository root:

1. Change into the example directory:

   ```bash
   cd examples/basic
   ```

2. Create a working tfvars file:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit `terraform.tfvars` to match your environment.

4. Apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Required variables

All examples expect the following variables:

```hcl
proxmox_url      = "https://PROXMOX-IP:8006/api2/json"
proxmox_token    = "USER@REALM!tokenid=TOKEN_SECRET"
proxmox_insecure = true
proxmox_node     = "pve"
proxmox_host     = "PROXMOX-IP"
```

Notes:

- Set `proxmox_insecure = false` when your Proxmox API endpoint has a valid TLS certificate.
- Create an API token in the Proxmox UI under **Datacenter → Permissions → API Tokens**.
- The module and examples expect a single `proxmox_token` string in the format:
  - `<user>@<realm>!<tokenid>=<token_secret>`

## Example tfvars

Example: `examples/basic/terraform.tfvars.example`

```hcl
proxmox_url      = "https://192.168.1.10:8006/api2/json"
proxmox_token    = "root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
proxmox_insecure = true

proxmox_node = "pve"
proxmox_host = "192.168.1.10"
```

You can use this as a starting point and adjust IPs, node names, and credentials to match your environment.