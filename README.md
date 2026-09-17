# IAM-lab
Hands-on enterprise hybrid identity lab: Windows Server Domain Controller promotion, idempotent PowerShell automation for bulk OU, group, and user onboarding via CSV, lifecycle attribute updates, and local application integration with Okta across SAML 2.0, OIDC, SWA, and OAuth 2.0 API protection tested with ngrok tunnels.


# Enterprise Identity & Access Management Lab: Active Directory to Okta Integration

A complete, end-to-end infrastructure and identity engineering lab. This repository documents the entire lifecycle of building an on-premises Windows Server Domain Controller (`Marvel.local`), developing idempotent PowerShell automation pipelines for bulk OU, group, and user onboarding, managing user attributes, and preparing local web applications for cloud SSO federation (SAML 2.0, OIDC, SWA, and OAuth 2.0 API protection) with Okta.

---

## 🏗️ Architecture & Lab Blueprint

```text
[ On-Premises Active Directory DS ]              [ Cloud Identity Provider ]
   Domain: Marvel.local                                Okta Dev Tenant
  ┌─────────────────────────────────┐                 ┌──────────────────┐
  │  OU=Marvel-Employees            │                 │                  │
  │  ├── OU=Engineering (7 users)   │   Provision /   │ Directory Sync   │
  │  ├── OU=IT          (8 users)   │ ══════════════> │ Applications:    │
  │  ├── OU=HR          (7 users)   │ Hybrid Identity │  - SAML 2.0      │
  │  ├── OU=Finance     (7 users)   │                 │  - OIDC Web App  │
  │  ├── OU=Sales       (4 users)   │                 │  - SWA Form      │
  │  └── OU=Marketing   (4 users)   │                 │  - OAuth 2.0 API │
  └─────────────────────────────────┘                 └────────┬─────────┘
                   ▲                                           │
                   │ PowerShell Automation Pipelines           │ Public Ingress
                   └────────── [ CSV Datasets ]                ▼ (HTTPS Tunnels)
                                                        [ Local Mock Apps ]
                                                        (Node.js / Docker)
