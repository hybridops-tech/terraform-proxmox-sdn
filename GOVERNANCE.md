# Governance

## Project scope

`terraform-proxmox-sdn` is maintained as an open-source HybridOps project. Its
scope is the lifecycle of Proxmox SDN zones, VNets and subnets, with optional
host-side gateway, routing, NAT and DHCP operations.

## Roles

The project currently has one lead maintainer:

- [Jeleel Muibi](https://github.com/jeleel-muibi): project direction, review,
  releases and security coordination.

Contributors may propose changes, review work and help with issue triage. Merge,
release and security-advisory authority remains with the lead maintainer until
another maintainer is appointed and recorded in this document.

## Decisions and changes

- User-visible and implementation changes are proposed through issues,
  discussions or pull requests.
- Substantive changes ordinarily enter `main` through a reviewed pull request
  and must pass the relevant automated checks.
- Compatibility, privilege boundaries and destructive behaviour require tests
  or a documented validation record.
- Decisions are made in public unless they concern an undisclosed security
  issue or private user data.
- The lead maintainer makes the final decision when consensus is not reached
  and records the reason on the relevant issue or pull request.

## Releases

The lead maintainer controls versioning and release tags. A release should have
passing CI, an updated changelog and documentation for user-visible changes.
Prereleases may be published for changes that need wider validation before a
stable release.

## Security

The lead maintainer is the current security lead. Vulnerabilities are handled
under [SECURITY.md](SECURITY.md). Security reports remain private until a fix or
coordinated disclosure decision is ready.

## Adding maintainers

Maintainers are appointed based on sustained contribution, sound review
judgement, respectful participation and willingness to share release and
security responsibilities. Appointments and departures are recorded through a
pull request to this document.

## Funding and independence

Funding does not grant merge authority or control over technical decisions.
Material funding that affects the public roadmap or release priorities will be
disclosed in the repository.
