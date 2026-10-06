# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The full stack for `beyondthefirewall.{io,me,org,app,co.uk,info,uk}`: a static
marketing site and the Terraform that manages Cloudflare around it.
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
  `sitemap.xml`, `og-image.png` — the public marketing site plus the
  Access-gated members page and its client-side connection diagnostics. No
  build step; these files are served as-is.
- `infra/` — Terraform, split by concern (see below).
- `.github/workflows/` — the deploy/monitoring pipelines.

## Commands

There is no root `package.json`, and no test suite anywhere in this repo.

**Terraform** (`cd infra/warp-pi-access` or `cd infra/cloudflare` — two
separate projects, see Infra below):
```
terraform init
terraform plan
terraform apply
```
State is remote for both (Cloudflare R2 bucket `beyondthefirewall-tfstate`,
S3-compatible backend, separate key per project). Never put
`cloudflare_api_token` in a `.tfvars` file or env var — enter it at the
masked interactive prompt only (see `infra/README.md` for why).

## Architecture

### Deploys (`.github/workflows/`)

A GitHub Actions job installs a pinned, checksum-verified `cloudflared`,
then SSHes to `ssh.beyondthefirewall.io` through `cloudflared access ssh` as
an SSH `ProxyCommand`, with strict host-key checking against the
`PI_KNOWN_HOSTS` secret. The Pi's `authorized_keys` forces the deploy key
into one fixed command server-side (`git pull`) — the SSH command in the
workflow YAML (`... true`) is just a placeholder, it has no effect on what
actually runs.

- `deploy-site.yml` triggers on changes to top-level `*.html`, `*.css`,
  `*.js`, image files (`*.svg`, `*.png`, `*.gif`, `*.webp`, `*.ico`),
  `robots.txt`, `sitemap.xml`. Secrets: `PI_DEPLOY_SSH_KEY`,
  `PI_KNOWN_HOSTS`, `CF_ACCESS_CLIENT_ID`, `CF_ACCESS_CLIENT_SECRET`.
- `uptime-check.yml` runs every 15 minutes, hits all seven domains'
  homepages — a failing run is the only alerting in place. GitHub disables
  scheduled workflows after 60 days of repo inactivity.
- `terraform-check.yml` runs `terraform fmt -check` and `terraform validate`
  (no backend, no credentials) on changes under `infra/`.

Pushing to `main` under a watched path deploys automatically; there is no
staging environment or manual approval gate.

### Infra (`infra/`)

Two Terraform projects, deliberately separate (own state key, own API
token each — see `infra/README.md`'s Terraform section for exactly which
resources each one owns and why):

- `warp-pi-access/` — the original, Pi-specific project: Cloudflare
  Tunnel ingress routing all seven domains to the Pi, `.io`'s tunnel
  CNAME/MX DNS records, the browser-SSH console's Access
  application/policy/certificate, terminal SSH also behind Access (deploy
  uses a service token), canonical-domain Bulk Redirects to `.me`
  (`redirects.tf`), and edge-side SSH rate-limiting (fail2ban can't work
  here since Cloudflare Tunnel makes every SSH connection appear to come
  from 127.0.0.1).
- `cloudflare/` — broader, added 6 Oct 2026 as a bulk `import` of what
  had been dashboard-only: the rest of the DNS across all 7 zones,
  zone-level settings (TLS/HSTS/DNSSEC/bot management), WAF/rate-limit/
  security-header rulesets, the Members Area and SSH-`.io` Access apps,
  and tunnel health notifications.

Both projects now hold all 7 zones' `zone_id`s — none of this is
dashboard-only anymore. If a zone's live config ever looks like it's
drifted from what either project declares, that's real drift (changed by
hand since), not an intentionally-unmanaged setting.

(A former `prisma-mtls/` demo — mTLS client-cert gating via Prisma
Access Browser, fronting its own Cloud Run service — used to live here
too. Both its GCP and Cloudflare halves were torn down and the directory
deleted once the `beyondthefirewall` GCP project itself was shut down;
see the GCP section of `infra/README.md` if this ever comes up in git
history.)
