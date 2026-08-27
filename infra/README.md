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
itself isn't Terraform-managed, we don't have its original secret), the
tunnel's ingress config (which also includes the apex/`www` hostnames for
`.me`, `.org`, `.app`, `.co.uk`, `.info`, and `.uk`, since tunnel ingress
is an account-level resource, not tied to a single zone), and the SSH
rate-limiting ruleset.

`.me`, `.org`, `.app`, `.co.uk`, `.info`, and `.uk`'s actual DNS records
live in **separate Cloudflare zones** this project doesn't hold
`zone_id`s for, so they're dashboard-managed, not Terraform — same as
before. If any of them ever diverges from `.io` in how it's routed, check
the dashboard for that zone, not just this Terraform config.

State lives in a versioned, private GCS bucket (`beyondthefirewall-tfstate`,
prefix `warp-pi-access`), not locally. `terraform init` picks up the
backend automatically from `main.tf`. Auth for the GCS backend uses your
own Application Default Credentials (`gcloud auth application-default
login`) — if that's ever reconfigured to impersonate a service account
your account can't impersonate (as happened once already), `terraform
init`/`plan` will fail with a `PERMISSION_DENIED` on
`iam.serviceAccounts.getAccessToken`; fix is to rerun that login command
without impersonation.

Run `terraform apply` from `infra/warp-pi-access/` — it'll prompt for
`cloudflare_account_id`, `cloudflare_api_token` (paste at the masked
prompt, don't set it as an env var — that lands in shell history in
plaintext), and `cloudflare_zone_id` (this is `.io`'s zone ID, even though
the config now also touches `.me`, `.org`, `.app`, `.co.uk`, `.info`, and
`.uk` hostnames via the tunnel ingress).

## GCP

The member/login area and Firebase Authentication have been removed
entirely (Node app deleted, DNS/WAF rules for `/members/*` cleaned up —
see git history around the removal commit for what changed). The
`beyondthefirewall` GCP project is no longer used for the live site at
all; the only things left in it are:

- The `beyondthefirewall-tfstate` GCS bucket (fractions of a cent/month,
  unrelated to hosting — just where this Terraform project's state lives)
- The `infra/prisma-mtls/` demo (Prisma Access Browser client-cert
  gating), separately queued for teardown — see that Terraform's own
  state/comments

`members-backend@beyondthefirewall.iam.gserviceaccount.com` and its key
on the Pi are no longer used and can be deleted/revoked next time GCP
access is available.

Everything else — `web-01`, the old `members.beyondthefirewall.me` load
balancer stack, the `members-backend` Cloud Run service, the
`github-actions-deploy` service account and its Workload Identity
Federation setup, the `proxy-shared-secret` Secret Manager secret — was
torn down when this moved to the Pi. If you see any of those names again
in GCP, something didn't get cleaned up.

## Security headers, HSTS, DNSSEC, SPF/DKIM/DMARC

All applied at the Cloudflare zone level for every domain (dashboard, not
Terraform) — HSTS (6mo, no includeSubDomains/preload), minimum TLS 1.2,
DNSSEC, and SPF/DKIM/DMARC records that explicitly reject all mail (none
of these domains send email). nginx also sets `X-Content-Type-Options`,
`X-Frame-Options`, `Referrer-Policy`, and a CSP.

Cloudflare's "Leaked Credential Check" rate-limiting rule (the
`cf.waf.credential_check.password_leaked` template, under Security >
Settings > "Rate limit authentication requests") is live on `.me`, `.org`,
`.app`, `.co.uk`, `.info`, and `.uk`, but **not** `.io` — the free plan
allows only one rate-limiting rule per zone, and `.io`'s is already used
by SSH protection.
