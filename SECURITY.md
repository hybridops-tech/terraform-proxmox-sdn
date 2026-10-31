# Security policy

## Supported versions

Security fixes are applied to the latest stable release. The current beta line
is reviewed on a best-effort basis while it remains under active development.

| Version | Support |
| --- | --- |
| `0.1.x` latest release | Supported |
| `0.2.0-beta.x` latest prerelease | Best effort |
| Earlier releases | Not supported |

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability.

Use [GitHub private vulnerability reporting](https://github.com/hybridops-tech/terraform-proxmox-sdn/security/advisories/new)
or email `security@hybridops.tech`. Include:

- the affected release or commit;
- the operating mode and relevant inputs;
- the security impact;
- reproduction steps or a minimal proof of concept; and
- any suggested mitigation.

Remove API tokens, SSH keys, private addresses and customer data. A report will
normally be acknowledged within three working days. Triage, remediation and
disclosure timing will depend on severity and reproducibility.

## Security boundary

The module has two distinct operating modes:

- API-only mode manages Proxmox SDN objects through a Proxmox API token.
- Host-routed mode can also execute network changes as `root` on one selected
  Proxmox node through SSH.

The host-routed boundary is privileged. Operators should use a dedicated API
token, verify TLS, restrict SSH access to the runner, review every plan and test
changes away from production first. Terraform state can contain sensitive
infrastructure data and must be stored accordingly.

## Disclosure

Please allow time for a fix and supported-release guidance before publishing a
report. The project will credit reporters unless they request otherwise. There
is currently no paid bug-bounty programme.
