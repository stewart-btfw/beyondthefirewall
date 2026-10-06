# Cloudflare — beyondthefirewall (imported from dashboard, 6 Oct 2026)

Brings the dashboard-managed config for all 7 zones under Terraform using
`import` blocks (Terraform >= 1.7, Cloudflare provider ~> 5.0). Nothing is
created or destroyed — the first apply only adopts existing resources.

This is a separate Terraform project from `infra/warp-pi-access/` — own
state (same R2 bucket, own key, see `versions.tf`), own API token. A few
resources that `warp-pi-access` already manages were deliberately left out
of the import here to avoid two projects owning the same live object; each
spot says so with a comment naming which project has it instead.

## What's covered
| File | Resources |
|---|---|
| dns.tf | DNS records for all 7 zones (null MX, SPF, DMARC+rua, null DKIM, Google verification, tunnel CNAMEs for the other 6 domains) — `.io`'s 5 tunnel CNAME/MX records excluded, see `warp-pi-access` |
| zone_settings.tf | 14 settings × 7 zones, HSTS/nosniff, DNSSEC, bot management |
| rulesets.tf | WAF custom rules, rate limiting, security response headers — all 7 zones, including `.io` |
| access.tf | 2 reusable policies (Members Area, BeyondTheFirewall/WARP enrolment), 2 Access apps (SSH `.io`, Members Area) — the Console SSH policy+app excluded, see `warp-pi-access` |
| tunnel.tf | The BTFW tunnel's own identity (name, config_src) only — its ingress config is `warp-pi-access`'s |
| notifications.tf | Tunnel health alert |

Not covered: Warp Login App, Gateway rule, device profiles, billing alert,
DMARC Management toggle (its only footprint is the `rua=` in the DMARC record).

## Steps
1. Create an API token (Cloudflare dashboard → My Profile → API Tokens →
   Create Token → Custom token) with: Zone DNS/Zone Settings/WAF/Bot
   Management/Transform Rules (Edit) on all 7 zones, Account Access Apps
   and Policies/Cloudflare Tunnel/Notifications (Edit). Give it an expiry.
2. Set `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` for the R2 backend (same
   credential as `warp-pi-access` — see its README section).
3. `terraform init && terraform plan` from this directory — paste the
   token at the masked prompt, never as an env var or in a file.
   - Expect: `N to import, 0 to add, 0 to change, 0 to destroy`.
   - If an import ID format is rejected, the error says the expected format
     — adjust that one `import` block.
   - Small "update in-place" diffs (e.g. a default the API fills in) are
     fine to accept or copy back into the `.tf`; anything marked
     **replace** or **destroy** — stop and investigate before applying.
4. `terraform apply`, then delete the `import` blocks (optional, they're
   no-ops afterwards).

After this, make changes here rather than in the dashboard, or drift returns.
