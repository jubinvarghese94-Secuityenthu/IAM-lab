# Enterprise Identity & Access Management Lab: Windows Server Active Directory to Okta Cloud

An end-to-end hands-on hybrid identity lab documenting the complete build-out: installing and promoting a Windows Server Active Directory Domain Controller (`Marvel.local`), automated bulk provisioning via PowerShell and CSV data pipelines, setting up an Okta Developer tenant, user lifecycle attribute manipulation, and preparing local ingress for SAML 2.0, OIDC, SWA, and API authentication testing.

---

## 🏗️ Architecture & Lab Blueprint

```text
[ On-Premises AD DS ]                       [ Cloud Identity Provider ]
   Domain: Marvel.local                             Okta Dev Tenant
  ┌─────────────────────────┐                     ┌──────────────────┐
  │  OU=Marvel-Employees    │                     │                  │
  │  ├── OU=Engineering     │    Provision /      │ Directory Sync   │
  │  ├── OU=IT              │ ══════════════════> │ Applications:    │
  │  ├── OU=HR              │   Hybrid Identity   │  - SAML 2.0      │
  │  ├── OU=Finance         │                     │  - OIDC Web App  │
  │  ├── OU=Sales           │                     │  - SWA Form      │
  │  └── OU=Marketing       │                     │  - OAuth 2.0 API │
  └─────────────────────────┘                     └────────┬─────────┘
               ▲                                           │
               │ PowerShell Batch Pipelines                │ Public Ingress
               └──────── [ CSV Data Source ]               ▼ (HTTPS Tunnels)
                                                    [ Local Mock Apps ]
                                                    (Node.js / Docker)
```

* **Target Domain:** `Marvel.local`
* **Domain Controller Role:** Windows Server (AD DS, DNS)
* **Parent Organizational Unit:** `OU=Marvel-Employees,DC=MARVEL,DC=local`
* **Department Units:** `Engineering`, `IT`, `HR`, `Finance`, `Sales`, `Marketing`
* **Security Groups:** `SG-Engineering`, `SG-IT`, `SG-HR`, `SG-Finance`, `SG-Sales`, `SG-Marketing`
* **Total Provisioned Users:** 40 identities mapped across all 6 departments
* **Identity Provider (IdP):** Okta Developer Workforce Identity Cloud
* **Ingress / Tunnels:** `ngrok` (reverse proxy for local SAML/OIDC redirects)

---

## 📋 Comprehensive Phase-by-Phase Implementation

### Phase 1: Windows Server Domain Controller Deployment

1. **Host Configuration & Static IP Allocation:**
   * Assigned a static private IPv4 address to the server interface.
   * Configured primary DNS pointing to `127.0.0.1` (loopback).

2. **Active Directory Domain Services (AD DS) Role Installation:**
   * Installed AD DS binaries and administration snap-ins via PowerShell:
     ```powershell
     Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
     ```

3. **Forest Promotion (`Marvel.local`):**
   * Promoted the server to the root domain controller of a new forest:
     ```powershell
     Install-ADDSForest -DomainName "Marvel.local" -DomainMode WinThreshold -ForestMode WinThreshold -InstallDns:$true -Force
     ```
   * Completed reboot into the domain environment as `MARVEL\Administrator`.

4. **Management Tooling Verification:**
   * Verified MMC administrative snap-ins (`dsa.msc` for ADUC, `dsac.exe` for Active Directory Administrative Center):
     ```powershell
     Install-WindowsFeature RSAT-ADDS-Tools
     ```

---

### Phase 2: Schema Design & PowerShell Automation

To avoid error-prone manual clicking in the GUI, the directory hierarchy, security groups, and user accounts were fully automated using declarative CSV templates and PowerShell.

#### 1. Data Schema Definitions
* **`groups.csv`**: Maps department names to OU containers and global security groups.
  ```csv
  OUName,GroupName,Description
  Engineering,SG-Engineering,Engineering department members
  IT,SG-IT,IT operations and infrastructure
  HR,SG-HR,Human Resources and People operations
  Finance,SG-Finance,Financial operations and accounting
  Sales,SG-Sales,Sales operations and business development
  Marketing,SG-Marketing,Brand strategy and marketing
  ```
* **`users.csv`**: Contains structured employee records (FirstName, LastName, SamAccountName, Department, Title, Password, Group).

#### 2. Automated OU and Group Provisioning (`01-create-ous-and-groups.ps1`)
* Created the parent root container `OU=Marvel-Employees,DC=MARVEL,DC=local`.
* Iterated through `groups.csv` to idempotently provision each child departmental OU.
* Instantiated Global Security Groups inside their corresponding OU containers.

#### 3. Bulk User Provisioning & Group Binding (`02-bulk-provision-users.ps1`)
* Ingested 40 employee records from `users.csv`.
* Automatically constructed dynamic User Principal Names (`$User.SamAccountName@Marvel.local`).
* Converted plain-text default credentials to encrypted secure strings (`ConvertTo-SecureString`).
* Enforced password change upon first interactive login (`-ChangePasswordAtLogon $true`).
* Injected user accounts directly into their department-specific OU.
* Dynamically resolved and appended each user into their designated security group (`Add-ADGroupMember`).

#### 4. Active Directory Validation
Verified the deployment directly via PowerShell:
```powershell
# Verify OU Structure
Get-ADOrganizationalUnit -Filter * -SearchBase "OU=Marvel-Employees,DC=Marvel,DC=local" | Select-Object Name, DistinguishedName

# Verify Department Breakdown
Get-ADUser -Filter * -SearchBase "OU=Marvel-Employees,DC=Marvel,DC=local" -Properties Department | Group-Object Department | Select-Object Name, Count

# Verify Security Group Membership Totals
Get-ADGroup -Filter "Name -like 'SG-*'" | ForEach-Object {
    [PSCustomObject]@{
        GroupName   = $_.Name
        MemberCount = (Get-ADGroupMember -Identity $_.SamAccountName).Count
    }
}
```

---

### Phase 3: Identity Lifecycle Management & Attribute Modification

Simulated an enterprise identity migration where select personnel had their primary e-mail addresses modified for cloud federation sync:

* **Target Accounts:** `lcage`, `bdrake`, `pcoulson`, `nfury`, `bbarnes`, `cbarton`, `cdanvers`, `bbanner`, `fcastle`.
* **Execution (`03-bulk-update-emails.ps1`):**
  Programmatically updated the AD `mail` attribute:
  ```powershell
  $UserList = @("lcage","bdrake","pcoulson","nfury","bbarnes","cbarton","cdanvers","bbanner","fcastle")
  foreach ($Username in $UserList) {
      Set-ADUser -Identity $Username -EmailAddress "xcode143@gmail.com"
  }
  ```
* **Verification:**
  ```powershell
  $UserList | Get-ADUser -Properties EmailAddress | Select-Object Name, SamAccountName, EmailAddress
  ```

---

### Phase 4: Okta Developer Tenant Onboarding

1. **Tenant Provisioning:**
   * Registered a dedicated Okta Workforce Identity Cloud developer instance (`https://dev-XXXXXX.okta.com`).
   * Configured administrative access and MFA.

2. **Hybrid Integration Roadmapping:**
   * **Okta AD Agent (Direct Sync):** Architected directory replication between on-premises `Marvel.local` and Okta using the outbound-only Lightweight Okta Active Directory Agent.
   * **JIT (Just-In-Time) Provisioning:** Configured SAML/OIDC claim mappings for real-time account creation upon authentication.

---

### Phase 5: Local SSO App Integration & Network Ingress (SAML, OIDC, SWA, API)

Cloud-hosted Okta requires accessible public endpoints to deliver authentication tokens and browser redirects to applications running on `localhost`.

#### 1. Ingress Tunnel Configuration
* Installed and configured `ngrok` to expose local ports over encrypted HTTPS tunnels:
  ```powershell
  winget install ngrok.ngrok
  ngrok config add-authtoken <YOUR_TOKEN>
  ngrok http 3000
  ```

#### 2. Protocol Integration Patterns Tested
* **OIDC (OpenID Connect):**
  * Integrated an Express/Node.js application using Authorization Code Flow with PKCE.
  * Configured Okta Sign-in redirect URI: `https://<ngrok-id>.ngrok-free.app/authorization-code/callback`.
  * Verified ID Token and Access Token issuance.
* **SAML 2.0:**
  * Deployed a mock Service Provider container (`kristophj/saml-sp`).
  * Mapped Okta ACS URL (`https://<ngrok-id>.ngrok-free.app/saml/acs`) and SP Entity ID.
  * Configured Okta to release SAML assertions containing user claims (First Name, Department, Security Groups).
* **SWA (Secure Web Authentication):**
  * Built a standalone HTML legacy credential form.
  * Mapped CSS selectors (`#txt-user`, `#txt-pass`, `#btn-submit`) into Okta SWA templates with the Okta Browser Plugin.
* **OAuth 2.0 Protected APIs:**
  * Implemented JWT bearer-token verification middleware using `@okta/jwt-verifier`.
  * Enforced authorization server scope checks (`read:messages`).

---

## 📁 Repository Structure

```text
├── .gitignore
├── README.md
├── data/
│   ├── groups.csv                 # Department OU and Security Group schema
│   ├── users.sample.csv           # Sanitized sample user dataset
│   └── users.csv                  # Full 40-user import list (gitignored)
├── scripts/
│   ├── 01-create-ous-and-groups.ps1  # Automated AD DS container creation
│   ├── 02-bulk-provision-users.ps1   # Bulk account creation and group assignment
│   └── 03-bulk-update-emails.ps1     # User lifecycle attribute management
└── docs/
    ├── active-directory-setup.md  # Verification outputs and forest details
    └── okta-integration-guide.md  # Detailed configuration steps for SAML, OIDC, SWA & API
```

---

## ⚡ Quickstart & Execution

```powershell
# 1. Clone the repository
git clone [https://github.com/](https://github.com/)<YOUR_USERNAME>/marvel-ad-okta-lab.git
cd marvel-ad-okta-lab

# 2. Build the directory OU hierarchy and Security Groups
.\scripts\01-create-ous-and-groups.ps1

# 3. Provision the 40 user accounts
.\scripts\02-bulk-provision-users.ps1

# 4. Update email attributes for specific accounts
.\scripts\03-bulk-update-emails.ps1
```
