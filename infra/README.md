# Infrastructure overview

`beyondthefirewall.io`, `.me`, `.org`, `.app`, `.co.uk`, `.info`, and `.uk`
all run entirely from the home Raspberry Pi ("lenoir") now — no GCP compute
at all, and no member/login area either (removed along with Firebase
Authentication — see the GCP section below).

Everything reaches the Pi via a single Cloudflare Tunnel (`cloudflared`,
no port forwarding on the home router). All seven domains' DNS (apex +
`www`) CNAME to the tunnel and are proxied through Cloudflare's edge.

| | |
|---|---|
| Web server | nginx, config at `/etc/nginx/sites-available/raspberrypistatic.conf` |
| Static docroot | `/var/www/html` — full git checkout of this repo |
| SSH access | `ssh.beyondthefirewall.io` via Cloudflare Tunnel, key-only auth, edge rate-limited |

Deploys reach the Pi via `cloudflared access ssh` as an SSH `ProxyCommand`,
with a forced command in `authorized_keys` so the deploy key can only do
exactly one thing:

- [`deploy-site.yml`](../.github/workflows/deploy-site.yml) — static site changes (`index.html`, `style.css`, etc.) trigger a `git pull` in `/var/www/html`

## Terraform

`warp-pi-access/` manages the Cloudflare side: DNS records for `.io`
(`web`/`ssh`/`www`/apex — all CNAMEs to the "BTFW" tunnel; the tunnel
itself isn't Terraform-managed, we don't have its original secret — plus
a null MX on the apex, RFC 7505, declaring it takes no mail), the
tunnel's ingress config (which also includes the apex/`www` hostnames for
`.me`, `.org`, `.app`, `.co.uk`, `.info`, and `.uk`, since tunnel ingress
is an account-level resource, not tied to a single zone), and the SSH
rate-limiting ruleset.

`.me`, `.org`, `.app`, `.co.uk`, `.info`, and `.uk`'s actual DNS records
live in **separate Cloudflare zones** this project doesn't hold
`zone_id`s for, so they're dashboard-managed, not Terraform — same as
before. If any of them ever diverges from `.io` in how it's routed, check
the dashboard for that zone, not just this Terraform config.

State lives in a Cloudflare R2 bucket (`beyondthefirewall-tfstate`, S3-compatible
backend), not GCS — GCP is no longer used for anything in this repo. Auth for
the backend is an R2 (Account) API token's Access Key ID / Secret Access Key,
supplied via the `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` environment
variables in your shell before running `terraform init`/`plan`/`apply` — never
committed to a file, and never the same credential as `cloudflare_api_token`
(that one's a regular Cloudflare API token for the `cloudflare` provider; this
one's a separate R2-scoped S3 credential for the backend).

Run `terraform apply` from `infra/warp-pi-access/` — it'll prompt for
`cloudflare_account_id`, `cloudflare_api_token` (paste at the masked
prompt, don't set it as an env var — that lands in shell history in
plaintext), and `cloudflare_zone_id` (this is `.io`'s zone ID, even though
the config now also touches `.me`, `.org`, `.app`, `.co.uk`, `.info`, and
`.uk` hostnames via the tunnel ingress). It also needs `cloudflare_team_name`
(your Zero Trust team name) and `console_allowed_emails` (the browser-SSH
allowlist, below) — pass these as `-var` flags or in a `.tfvars` file
(neither is a credential, so unlike `cloudflare_api_token` they're fine to
write down).

### Browser SSH (`console.beyondthefirewall.me`)

Cloudflare Access can render an SSH terminal directly in the browser —
no backend of ours involved, Cloudflare does it — gated by the same kind
of email-allowlist Access policy as `members.html`. It's on its own
hostname (`console_hostname`) rather than `ssh.beyondthefirewall.io`,
so it doesn't touch the key-only SSH access that already works today.

Terraform creates the Access application, its email-allowlist policy
(`console_allowed_emails`), the short-lived-certificate CA, and the
tunnel ingress rule gating `ssh://localhost:22` behind that Access app.
Three things it can't do, left for a human:

1. **DNS**: add a CNAME for `console_hostname` to `<tunnel_id>.cfargotunnel.com`
   (proxied) in the `.me` zone dashboard — same as every other `.me`
   hostname, since this project doesn't hold that zone's `zone_id`.
2. **Enable browser rendering**: Zero Trust > Access > Applications >
   "Console — Browser SSH" > Configure > Advanced settings > Browser
   rendering settings > select **SSH**. This toggle isn't exposed by the
   Cloudflare Terraform provider yet, so it has to be flipped by hand
   after every `terraform apply` that recreates the application.
3. **Create a matching Unix account per allowed email, and trust the CA**:
   Cloudflare's browser SSH always connects using the authenticated
   email's local part as the login username (e.g. `stewart699700` for
   `stewart699700@icloud.com`) — there's no Terraform-exposed way to
   remap that to a shared account in the provider version pinned here
   (checked against the actual installed schema, `terraform providers
   schema -json`: `cloudflare_zero_trust_access_policy.connection_rules`
   only has an `rdp` sub-object, no `ssh` one, despite the upstream
   provider's own docs mentioning one — that's apparently unreleased).
   So for each email in `console_allowed_emails`, create a matching
   account on the Pi (`sudo useradd -m stewart699700`, set up its own
   `~/.ssh/` as needed for anything beyond the Access-issued cert).
   Then copy the Access application's SSH CA public key (same Advanced
   settings screen) to the Pi, e.g. `/etc/ssh/cloudflare_access_ca.pub`,
   add `TrustedUserCAKeys /etc/ssh/cloudflare_access_ca.pub` to
   `sshd_config` (or a file under `sshd_config.d/`), and reload sshd —
   sshd's default cert-principal check (principal must equal the
   requested username) does the rest, no `AuthorizedPrincipalsCommand`
   needed, now that principal and username are the same string by
   construction.

## GCP

The `beyondthefirewall` GCP project has been fully shut down and
deleted — nothing of this repo's hosting or infrastructure depends on
GCP anymore, and hasn't since the member/login area and Firebase
Authentication were removed (Node app deleted, DNS/WAF rules for
`/members/*` cleaned up — see git history around the removal commit).
`members-backend@beyondthefirewall.iam.gserviceaccount.com` and its key
on the Pi went with the project.

**One loose end this leaves**: `infra/prisma-mtls/cloudflare/main.tf`
still manages *live* Cloudflare resources — an mTLS certificate upload,
a hostname-certificate association, and an Access policy/application —
gating `beyondthefirewall.me/members/*`. Those were paired with
`infra/prisma-mtls/gcp/`'s load balancer + Cloud Run service, which no
longer exist now that the project is gone. The Cloudflare side is now
orphaned (gating a destination that 404s/times out, not a real backend)
rather than merely "queued for teardown." Next time you have the
Cloudflare API token handy:

```
cd infra/prisma-mtls/cloudflare
terraform destroy
```

Also worth checking the `.me` zone dashboard for any leftover DNS record
pointing `members.beyondthefirewall.me` at the old GCP load balancer's
IP — that's dashboard-managed, not Terraform, so `destroy` above won't
touch it. Once both are cleared, `infra/prisma-mtls/` (both halves) can
be deleted from this repo entirely rather than kept as a teardown
reminder.

Everything else — `web-01`, the old `members.beyondthefirewall.me` load
balancer stack, the `members-backend` Cloud Run service, the
`github-actions-deploy` service account and its Workload Identity
Federation setup, the `proxy-shared-secret` Secret Manager secret — was
torn down when this moved to the Pi, well before the project deletion.

## Security headers, HSTS, DNSSEC, SPF/DKIM/DMARC

All applied at the Cloudflare zone level for every domain (dashboard, not
Terraform) — HSTS (6mo, includeSubDomains on, preload off), minimum TLS
1.2, DNSSEC, and SPF/DKIM/DMARC records that explicitly reject all mail
(none of these domains send email). nginx also sets
`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, and a CSP.

Cloudflare's "Leaked Credential Check" rate-limiting rule (the
`cf.waf.credential_check.password_leaked` template, under Security >
Settings > "Rate limit authentication requests") is live on `.me`, `.org`,
`.app`, `.co.uk`, `.info`, and `.uk`, but **not** `.io` — the free plan
allows only one rate-limiting rule per zone, and `.io`'s is already used
by SSH protection.
