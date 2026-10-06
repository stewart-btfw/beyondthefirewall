# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The full stack for `beyondthefirewall.{io,me,org,app,co.uk,info,uk}`: a static
marketing site and the Terraform that manages Cloudflare/GCP around it.
There is no build system tying these together — each top-level piece
deploys independently.

Everything runs on a home Raspberry Pi ("lenoir") reached only via a
Cloudflare Tunnel — no port forwarding, no cloud compute for hosting. There
is no member/login area or Firebase Authentication in this repo anymore —
it was deliberately removed (Node app, admin-invite tooling, and deploy
workflow all deleted) once Firebase/GCP became inaccessible for an extended
period; see git history around that removal commit for what was pulled out.
Read `infra/README.md` before touching anything infra- or deploy-related —
it's the authoritative, up-to-date description of the topology (nginx
config location, SSH access path, Terraform state, etc.) and is kept
current by whoever maintains this repo.

## Repo layout

- `index.html`, `members.html`, `style.css`, `diag.js`, `*.svg`, `robots.txt`,
  `sitemap.xml`, `waiting.gif` — the public marketing site plus the
  Access-gated members page and its client-side connection diagnostics. No
  build step; these files are served as-is.
- `infra/` — Terraform, split by concern (see below).
- `.github/workflows/` — the deploy/monitoring pipelines.

## Commands

There is no root `package.json`, and no test suite anywhere in this repo.

**Terraform** (`cd infra/warp-pi-access` or `cd infra/prisma-mtls/{cloudflare,gcp}`):
```
terraform init
terraform plan
terraform apply
```
`warp-pi-access` state is remote (Cloudflare R2 bucket
`beyondthefirewall-tfstate`, S3-compatible backend); the other two
directories have no backend block configured. Never put
`cloudflare_api_token` in a `.tfvars` file or env var — enter it at the
masked interactive prompt only (see `infra/README.md` for why).

## Architecture

### Deploys (`.github/workflows/`)

A GitHub Actions job installs `cloudflared`, then SSHes to
`ssh.beyondthefirewall.io` through `cloudflared access ssh` as an SSH
`ProxyCommand`. The Pi's `authorized_keys` forces the deploy key into one
fixed command server-side (`git pull`) — the SSH command in the workflow
YAML (`... true`) is just a placeholder, it has no effect on what actually
runs.

- `deploy-site.yml` triggers on changes to `index.html`, `members.html`,
  `style.css`, `*.js`, `*.svg`, `robots.txt`, `sitemap.xml`.
- `uptime-check.yml` runs every 15 minutes, hits both domains' homepage —
  a failing run is the only alerting in place.

Pushing to `main` under a watched path deploys automatically; there is no
staging environment or manual approval gate.

### Infra (`infra/`)

- `warp-pi-access/` — the real, deployed infra: Cloudflare Tunnel ingress
  routing all seven domains to the Pi, DNS records, a browser-SSH console
  gated by Cloudflare Access, and edge-side SSH rate-limiting (fail2ban
  can't work here since Cloudflare Tunnel makes every SSH connection
  appear to come from 127.0.0.1). R2 remote state.
- `prisma-mtls/` — a separate, isolated demo/prototype (mTLS client-cert
  gating via Prisma Access Browser) that fronted a dedicated Cloud Run
  service (`members-backend-demo`) at `members.beyondthefirewall.me`,
  unrelated to anything else in this repo. Had both a `cloudflare/` and a
  `gcp/` half (GCP owned the mTLS-terminating load balancer + managed
  cert; Cloudflare owned the matching CA upload + non-identity Access
  policy). **The GCP project has since been fully shut down and
  deleted** — the `gcp/` half's resources no longer exist, so the
  `cloudflare/` half's resources (still live) now gate a destination
  that's gone. Needs `terraform destroy` run from `cloudflare/` next time
  the API token is handy, then both halves can be deleted from the repo —
  see the GCP section of `infra/README.md`.

Only `.io`'s DNS is Terraform-managed here (`cloudflare_zone_id` in
`warp-pi-access` is always `.io`'s zone). The other six domains' DNS records
live in separate Cloudflare zones this project doesn't hold zone IDs for and
are dashboard-managed — if one of them seems to be routed differently than
`.io`, check that zone's dashboard, not this Terraform.
