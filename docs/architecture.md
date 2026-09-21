# Architecture

## Azure Infrastructure (Completed)

| Resource | Value |
|---|---|
| Resource Group | `rg-gft-identitylab` |
| Virtual Network | `vnet-gft-identity` |
| Region | East US 2 |
| VNet address space | `10.0.0.0/16` |
| Server subnet | `snet-servers` — `10.0.1.0/24` |
| VM | `DC01` |
| OS | Windows Server 2022 Datacenter: Azure Edition x64 Gen2 |
| VM Size | `Standard_D2als_v7` (2 vCPU, 4 GiB RAM) |
| Private IP | `10.0.1.4`, static at the Azure NIC layer |

**Networking note:** Windows reports `DHCP Enabled = Yes` even with a static private IP configured — this is expected. Azure reserves the static IP at the NIC/platform layer rather than requiring it to be hardcoded inside the guest OS.

**Network security:** a scoped RDP rule (`Allow-RDP-MyIP`, TCP/3389, source = a single public IP, priority 310) replaced the default/broad RDP allow rule. Auto-shutdown is configured, and the VM is stopped/deallocated between lab sessions to control cost.

## Active Directory / Domain Controller (Completed)

`DC01` runs AD DS and DNS for a new forest, `corp.guardianlab.internal`. Verified via:

```powershell
hostname
Get-ADDomain
Get-ADForest
Get-Service DNS,NTDS
```

Results: hostname `DC01`; domain and forest both `corp.guardianlab.internal`; DNS and NTDS services both running.

## OU Structure (Completed)

```
corp.guardianlab.internal
└── GFT
    ├── Users
    │   ├── IT
    │   ├── Security
    │   ├── Human Resources
    │   ├── Finance
    │   └── Operations
    ├── Groups
    ├── Servers
    ├── Service Accounts
    ├── Administrative Accounts
    ├── Disabled Users
    └── Contractors
```

## End-to-End Flow

```
Employee Data (CSV)
        |
        v
PowerShell JML Automation
        |
        v
Active Directory Domain Services (corp.guardianlab.internal)
        |
        v
Group-based RBAC
        |
        v
Access Audit + Identity Control Validation
        |
        v
Microsoft Entra Cloud Sync  <-- agent installed/configured, sync not yet run
        |
        v
Microsoft Entra ID (MFA / Conditional Access / SSO)  <-- not yet configured
```

See [`hybrid-identity-progress.md`](hybrid-identity-progress.md) for exactly where this flow currently stops.
