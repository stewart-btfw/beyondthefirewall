# Infrastructure overview

Two independent origins serve the same content from this repo, kept in sync
by [`deploy-site.yml`](../.github/workflows/deploy-site.yml) on every push
to `main`:

| | `beyondthefirewall.me` | `beyondthefirewall.io` |
|---|---|---|
| Host | GCP VM `web-01` (`australia-southeast1-b`) | Home Raspberry Pi ("lenoir") |
| Reached via | Direct A record → Cloudflare-proxied | Cloudflare Tunnel (`cloudflared`, no port forwarding) |
| Web server | nginx, config at `/etc/nginx/sites-enabled/default` | nginx, config at `/etc/nginx/sites-available/raspberrypistatic.conf` |
| Docroot | `/var/www/html` — full git checkout of this repo | same |
| SSH access | IAP tunnel only, no public port (`gcloud compute ssh --tunnel-through-iap`) | `ssh.beyondthefirewall.io` via Cloudflare Tunnel, key-only auth, edge rate-limited |

## Members area

`/members/*` on both domains reverse-proxies to a single Cloud Run service,
`members-backend` (see `../members-backend/`). The Cloud Run service has to
stay publicly reachable (`ingress: all`) since the Pi has no private network
path to it — direct hits to its `*.run.app` URL are blocked by a shared
secret (`PROXY_SECRET`, GCP Secret Manager, secret name
`proxy-shared-secret`) that both nginx configs send as `X-Proxy-Secret` and
`server.js` validates. **If you ever rotate that secret**, update it in
Secret Manager, then update both nginx configs (search for
`X-Proxy-Secret`), in that order — updating nginx first would just 403
everyone until the secret's back in sync.

## Terraform

`warp-pi-access/` manages the Cloudflare side of the Pi's setup: DNS records
(`web`/`ssh`/`www`/apex, all CNAMEs to the existing "BTFW" tunnel — the
tunnel itself isn't Terraform-managed, we don't have its original secret),
the tunnel's ingress config, and the SSH rate-limiting ruleset.
`beyondthefirewall.me`'s DNS and `web-01`'s nginx config are **not**
Terraform-managed — they're hand-edited via SSH, same as they were before
this project started.

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
plaintext), and `cloudflare_zone_id`.

## GCP IAM

- `web-01` runs as `web01-runtime@beyondthefirewall.iam.gserviceaccount.com`
  (just `logging.logWriter` + `monitoring.metricWriter`) — not the default
  Compute Engine service account, which used to carry project-wide
  `roles/editor`.
- `github-actions-deploy@...` (used by all the GitHub Actions workflows)
  needs `roles/storage.admin` project-wide — this looks broader than it
  should be, but `gcloud run deploy --source` genuinely requires
  project-level `storage.buckets.list` to auto-discover its Cloud Build
  staging bucket, which can't be scoped to a single bucket. Narrowing this
  further would mean switching off `--source` deploys (build a Docker image
  and push it to a specific Artifact Registry repo instead) — not done yet.

## Security headers, HSTS, DNSSEC, SPF/DKIM/DMARC

All applied at the Cloudflare zone level for both domains (dashboard, not
Terraform) — HSTS (6mo, no includeSubDomains/preload), minimum TLS 1.2,
DNSSEC, and SPF/DKIM/DMARC records that explicitly reject all mail (neither
domain sends email). nginx on both origins also sets
`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, and a CSP
(tighter on the homepage, relaxed on `/members/*` for Firebase Auth).

Cloudflare's "Leaked Credential Check" rate-limiting rule is live on
`.me`'s `/members/login` but **not** `.io` — the free plan allows only one
rate-limiting rule per zone, and `.io`'s is already used by SSH protection.

