# Infrastructure overview

`beyondthefirewall.io`, `.me`, `.org`, `.app`, `.co.uk`, `.info`, and `.uk`
all run entirely from the home Raspberry Pi ("lenoir") now — no GCP compute
at all. GCP is only still used for Firebase Authentication (the identity
provider behind `/members/*`), which lives in the same `beyondthefirewall`
project but costs essentially nothing at this traffic level.

Everything reaches the Pi via a single Cloudflare Tunnel (`cloudflared`,
no port forwarding on the home router). All seven domains' DNS (apex +
`www`) CNAME to the tunnel and are proxied through Cloudflare's edge.

| | |
|---|---|
| Web server | nginx, config at `/etc/nginx/sites-available/raspberrypistatic.conf` |
| Static docroot | `/var/www/html` — full git checkout of this repo |
| SSH access | `ssh.beyondthefirewall.io` via Cloudflare Tunnel, key-only auth, edge rate-limited |
| Members backend | `members-backend` systemd service, Node 20, port 8080, only reachable via nginx |

Deploys are two separate GitHub Actions workflows, both reaching the Pi
the same way (`cloudflared access ssh` as an SSH `ProxyCommand`, forced
commands in `authorized_keys` so each deploy key can only do exactly one
thing):

- [`deploy-site.yml`](../.github/workflows/deploy-site.yml) — static site changes (`index.html`, `style.css`, etc.) trigger a `git pull` in `/var/www/html`
- [`deploy-members-backend.yml`](../.github/workflows/deploy-members-backend.yml) — changes under `members-backend/` trigger `git pull && npm install && npm run build && sudo systemctl restart members-backend` (that `sudo` works passwordless only for this one exact command, via `/etc/sudoers.d/members-backend-restart`)

## Members area

`/members/*` on both domains reverse-proxies to the local
`members-backend` service (`http://127.0.0.1:8080`) — not Cloud Run
anymore. It authenticates to Firebase Admin SDK via a downloaded service
account key (`/etc/members-backend/firebase-key.json` on the Pi, owned
`liversalts:liversalts`, `chmod 600`, referenced by
`GOOGLE_APPLICATION_CREDENTIALS` in the systemd unit) rather than GCP's
metadata server, since the Pi isn't GCP infrastructure. If that key is
ever lost or needs rotating: `gcloud iam service-accounts keys create` for
`members-backend@beyondthefirewall.iam.gserviceaccount.com`, copy it to
the Pi via `scp` (never paste key contents into chat), swap the file, then
`sudo systemctl restart members-backend`.

nginx also still sends an `X-Proxy-Secret` header that `server.js`
validates (`PROXY_SECRET` env var in the systemd unit) — this was
originally defense-in-depth against direct hits to Cloud Run's public
`*.run.app` URL bypassing nginx's rate limiting. That specific threat no
longer exists (the service has no public URL of its own now, only
reachable via nginx on localhost), but the check is harmless to leave in
place.

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

Deliberately minimal now — just what Firebase Authentication needs:

- The `beyondthefirewall` project itself, kept for Firebase Auth
- `members-backend@beyondthefirewall.iam.gserviceaccount.com`, scoped to
  just `roles/firebaseauth.admin`, with a key file living on the Pi (see
  above)
- The `beyondthefirewall-tfstate` GCS bucket (fractions of a cent/month,
  unrelated to hosting — just where this Terraform project's state lives)

Everything else — `web-01`, the `members.beyondthefirewall.me` load
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
`X-Frame-Options`, `Referrer-Policy`, and a CSP (tighter on the homepage,
relaxed on `/members/*` for Firebase Auth).

Cloudflare's "Leaked Credential Check" rate-limiting rule (the
`cf.waf.credential_check.password_leaked` template, under Security >
Settings > "Rate limit authentication requests") is live on `.me`, `.org`,
`.app`, `.co.uk`, `.info`, and `.uk`, but **not** `.io` — the free plan
allows only one rate-limiting rule per zone, and `.io`'s is already used
by SSH protection.
