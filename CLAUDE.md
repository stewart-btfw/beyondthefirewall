# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The full stack for `beyondthefirewall.{io,me,org,app,co.uk,info,uk}`: a static
marketing site, a small Express "members area" app (Firebase-authenticated,
MFA-gated), the admin CLI that provisions member accounts, and the Terraform
that manages Cloudflare/GCP around it. There is no build system tying these
together — each top-level piece deploys independently.

Everything runs on a home Raspberry Pi ("lenoir") reached only via a
Cloudflare Tunnel — no port forwarding, no cloud compute for hosting. GCP is
kept around solely for Firebase Authentication. Read `infra/README.md`
before touching anything infra-, deploy-, or auth-related — it's the
authoritative, up-to-date description of the topology (nginx config
location, SSH access path, Terraform state, what was torn down when this
moved off Cloud Run, etc.) and is kept current by whoever maintains this repo.

## Repo layout

- `index.html`, `style.css`, `*.svg`, `robots.txt`, `sitemap.xml`, `waiting.gif`
  — the public marketing site. No build step; these files are served as-is.
- `members-backend/` — the Express app behind `/members/*`.
- `admin-scripts/` — standalone Node CLI for provisioning Firebase Auth users.
- `infra/` — Terraform, split by concern (see below).
- `.github/workflows/` — the three deploy/monitoring pipelines.

## Commands

There is no root `package.json`; each subproject has its own dependencies
and there is no test suite anywhere in this repo.

**members-backend** (`cd members-backend`):
```
npm install
npm run build   # esbuild-bundles public/{login,account,admin}.js -> public/dist/*.bundle.js
npm run dev      # build, then node server.js (serves on 127.0.0.1:8080)
npm start        # node server.js only (assumes public/dist/ already built)
```
`public/dist/` is gitignored and must be rebuilt after any change to
`public/login.js`, `public/account.js`, or `public/admin.js` — the server
does not bundle on the fly. The Docker build and the deploy workflow both
run `npm run build` for you; only run it manually for local iteration.

**admin-scripts** (`cd admin-scripts`):
```
npm install
cp invitees.example.csv invitees.csv   # fill in real emails, gitignored
gcloud auth application-default login --project beyondthefirewall
npm run invite   # or: node invite-users.js path/to/other.csv
```
Idempotent — safe to re-run, existing accounts are skipped.

**Terraform** (`cd infra/warp-pi-access` or `cd infra/prisma-mtls/{cloudflare,gcp}`):
```
terraform init
terraform plan
terraform apply
```
`warp-pi-access` state is remote (GCS bucket `beyondthefirewall-tfstate`);
the other two directories have no backend block configured. Never put
`cloudflare_api_token` in a `.tfvars` file or env var — enter it at the
masked interactive prompt only (see `infra/README.md` for why).

## Architecture

### members-backend (`members-backend/server.js`)

Single-file Express app, no framework/router abstraction — read it top to
bottom to understand the whole request lifecycle:

1. **Auth**: Firebase ID tokens (obtained client-side by `public/*.js` via
   the Firebase JS SDK) are exchanged for a first-party session cookie
   (`__session`, httpOnly, `path=/members/`, 5-day expiry) at
   `POST /members/session`, verified with Firebase Admin SDK. There is no
   server-side session store — the cookie *is* the session, verified against
   Firebase on every request via `verifySessionCookie`.
2. **Middleware chain**: routes compose `requireSession` → `requireAdmin` →
   `requireMfa` as needed. `requireMfa` deliberately excludes the account
   page itself, so an unenrolled member can still reach the page that lets
   them enroll. `requireAdmin` checks membership in the `ADMIN_EMAILS` env
   var, not a Firebase custom claim.
3. **Static content split**:
   - `public/` — login/account/admin app shell, always reachable pre-auth
     for login, gated by middleware for account/admin.
   - `gated-content/` — the actual members-only content, served only past
     `requireSession` + `requireMfa`.
   - Every dynamic/gated response sets `Cache-Control: no-store` explicitly
     (not just a short/absent max-age) because Cloudflare overrides
     unspecified caching on static-looking extensions with its own
     multi-hour default — this is the one directive it won't override.
4. **Audit logging**: `logAuthEvent()` writes structured JSON lines to
   stdout for every auth-relevant event (login, password reset request,
   MFA enrollment, admin actions) — outcome and email only, never a
   password or token. Follow this pattern for new sensitive actions.
5. **`PROXY_SECRET`**: `X-Proxy-Secret` header check, fails open if the env
   var is unset. This is a holdover from when the service also had a public
   Cloud Run URL; harmless to leave in place now that it's only reachable
   via nginx on localhost (see `infra/README.md`), but don't read the
   in-code comment as current architecture — the infra doc is authoritative.

Client-side (`public/login.js`, `public/account.js`, `public/admin.js`) use
the Firebase JS SDK directly for anything requiring a fresh sign-in
(password change, MFA enrollment) since Firebase requires re-authentication
for sensitive changes even with a valid session cookie — then re-POSTs
`/members/session` to reissue a cookie that reflects the new state (the
server's admin/MFA checks always do a fresh `admin.auth().getUser()` lookup
rather than trusting cached cookie claims). The Firebase web config
(`apiKey`, etc.) is intentionally hardcoded in these files — it's a public
client identifier, not a secret.

### Deploys (`.github/workflows/`)

Both site and backend deploys work the same way: a GitHub Actions job
installs `cloudflared`, then SSHes to `ssh.beyondthefirewall.io` through
`cloudflared access ssh` as an SSH `ProxyCommand`. The Pi's
`authorized_keys` forces each deploy key into one fixed command server-side
(`git pull` for the site; `git pull && npm install && npm run build &&
systemctl restart members-backend` for the backend) — the SSH command in
the workflow YAML (`... true`) is just a placeholder, it has no effect on
what actually runs.

- `deploy-site.yml` triggers on changes to `index.html`, `style.css`, `*.svg`,
  `robots.txt`, `sitemap.xml`.
- `deploy-members-backend.yml` triggers on changes under `members-backend/`.
- `uptime-check.yml` runs every 15 minutes, hits both domains' homepage and
  `/members/login` (a separate proxy path from the static homepage, so it's
  checked independently) — a failing run is the only alerting in place.

Pushing to `main` under a watched path deploys automatically; there is no
staging environment or manual approval gate.

### Infra (`infra/`)

- `warp-pi-access/` — the real, deployed infra: Cloudflare Tunnel ingress
  routing all seven domains to the Pi, DNS records, and edge-side SSH
  rate-limiting (fail2ban can't work here since Cloudflare Tunnel makes
  every SSH connection appear to come from 127.0.0.1). GCS remote state.
- `prisma-mtls/` — a separate, isolated demo/prototype (mTLS client-cert
  gating via Prisma Access Browser) fronting a *dedicated* Cloud Run service
  (`members-backend-demo`) at `members.beyondthefirewall.me`, fully
  decoupled from the production Pi-hosted `members-backend`. Has both a
  `cloudflare/` and a `gcp/` half that must be applied together (GCP owns
  the mTLS-terminating load balancer + managed cert; Cloudflare owns the
  matching CA upload + non-identity Access policy). No remote state backend
  configured for either half.

Only `.io`'s DNS is Terraform-managed here (`cloudflare_zone_id` in
`warp-pi-access` is always `.io`'s zone). The other six domains' DNS records
live in separate Cloudflare zones this project doesn't hold zone IDs for and
are dashboard-managed — if one of them seems to be routed differently than
`.io`, check that zone's dashboard, not this Terraform.
