# Cloudflare — beyondthefirewall (imported from dashboard, 6 Oct 2026)

Brings the dashboard-managed config for all 7 zones under Terraform using
`import` blocks (Terraform >= 1.7, Cloudflare provider ~> 5.0). Nothing is
created or destroyed — the first apply only adopts existing resources.

## What's covered
| File | Resources |
|---|---|
| dns.tf | 52 DNS records (tunnel CNAMEs, null MX, SPF, DMARC+rua, null DKIM, Google verification) |
| zone_settings.tf | 14 settings x 7 zones, HSTS/nosniff, DNSSEC, bot settings |
| rulesets.tf | WAF custom, rate limit, security response headers (x 7 zones) |
| access.tf | 3 reusable policies, 3 Access apps (SSH .io, Console SSH, Members Area) |
| tunnel.tf | BTFW tunnel + remotely-managed ingress config |
| notifications.tf | Tunnel health alert |

Not covered: Warp Login App, Gateway rule, device profiles, billing alert,
DMARC Management toggle (its only footprint is the `rua=` in the DMARC record).

## Steps
1. Put this in its own directory (e.g. `infra/cloudflare/`) so it doesn't
   collide with the existing .io config. Remove any overlapping resource there.
2. **Add a remote backend** in `versions.tf` — state will contain the full config.
3. Create an API token with: Zone DNS/Settings/WAF/Bot Management/Transform Rules
   (edit) on the 7 zones, Account Access Apps & Policies, Cloudflare Tunnel,
   Notifications (edit). Give it an expiry.
4. `export CLOUDFLARE_API_TOKEN=...`
5. `terraform init && terraform plan`
   - Expect: `N to import, 0 to add, 0 to change, 0 to destroy`.
   - If an import ID format is rejected, the error says the expected format —
     adjust that one `import` block.
   - Small "update in-place" diffs (e.g. a default the API fills in) are fine
     to accept or copy back into the .tf; anything marked **replace** or
     **destroy** — stop and investigate before applying.
6. `terraform apply`, then delete the `import` blocks (optional, they're no-ops afterwards).

After this, make changes here rather than in the dashboard, or drift returns.
