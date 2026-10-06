terraform {
  # State lives in Cloudflare R2 (S3-compatible), not GCS — GCP is no longer
  # used for anything in this repo. Credentials for this backend can't be a
  # Terraform variable (backend blocks are evaluated before variables), so
  # they're supplied via the AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
  # environment variables at `terraform init`/`plan`/`apply` time — set them
  # in your shell before running Terraform, never commit them to a file.
  backend "s3" {
    bucket = "beyondthefirewall-tfstate"
    key    = "warp-pi-access/terraform.tfstate"
    region = "auto"

    endpoints = {
      s3 = "https://2314a9913a2e9dadad8bb6d1625aa17b.r2.cloudflarestorage.com"
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Reuses the existing "BTFW" tunnel already running on the Pi (systemd
# service, currently connected) rather than creating a redundant second one.
# Not declared as a managed resource here — we don't know its original
# config_src/tunnel_secret, so we just point config/DNS at its known ID.

# Routes every site hostname (all seven domains) plus SSH and the console
# through the existing tunnel to services on the Pi.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "pi" {
  account_id = var.cloudflare_account_id
  tunnel_id  = var.tunnel_id
  source     = "cloudflare"

  config = {
    # Enables routing WARP client traffic through this tunnel (Zero Trust
    # private network access). Confirmed live via the full-account
    # Terraform import in infra/cloudflare/ — not something this project
    # turned on itself, but it must stay declared here or a plain `apply`
    # of this project alone would silently disable it.
    warp_routing = { enabled = true }

    # Order matters (first match wins) and is kept identical to the old
    # hand-written list, so this refactor plans as a no-op: .io web/apex/www,
    # .io ssh, then apex + www for every other domain, then the
    # Access-gated console, then the catch-all 404.
    ingress = concat(
      [for h in [var.web_hostname, var.apex_hostname, var.www_hostname] : {
        hostname = h
        service  = "http://localhost:${var.web_port}"
      }],
      # SSH for terminal clients (`cloudflared access ssh`). Access is
      # enforced at the tunnel too, not just at the edge, so the connection
      # never reaches the Pi's sshd without a valid token for
      # infra/cloudflare's "ssh_io" Access application — even if that app's
      # edge policy were ever misconfigured.
      [{
        hostname = var.ssh_hostname
        service  = "ssh://localhost:22"

        origin_request = {
          access = {
            required  = true
            team_name = var.cloudflare_team_name
            aud_tag   = [data.cloudflare_zero_trust_access_application.ssh_io.aud]
          }
        }
      }],
      flatten([for d in var.extra_site_domains : [
        for h in [d, "www.${d}"] : {
          hostname = h
          service  = "http://localhost:${var.web_port}"
        }
      ]]),
      # Browser-rendered SSH console. Unlike every other ingress rule above,
      # this one requires Access authorization at the tunnel itself — the
      # connection never reaches the Pi's sshd unless it already carries a
      # valid token for cloudflare_zero_trust_access_application.console_ssh.
      [{
        hostname = var.console_hostname
        service  = "ssh://localhost:22"

        origin_request = {
          access = {
            required  = true
            team_name = var.cloudflare_team_name
            aud_tag   = [cloudflare_zero_trust_access_application.console_ssh.aud]
          }
        }
      }],
      [{
        service = "http_status:404"
      }],
    )
  }
}

# Gates who can open a browser SSH session. The provider version pinned
# here (~> 5.0, resolves to 5.22.0 as of writing) has no SSH equivalent of
# connection_rules.rdp — there's no way to remap the login username via
# Terraform, so Cloudflare falls back to its documented default: the
# connecting username must equal the authenticated email's local part.
# That means a matching Unix account is required on the Pi per allowed
# email (see infra/README.md) — there's no single shared account here.
resource "cloudflare_zero_trust_access_policy" "console_ssh_allow" {
  account_id       = var.cloudflare_account_id
  name             = "Console SSH — allowed members"
  decision         = "allow"
  session_duration = "8h"

  include = [for e in var.console_allowed_emails : { email = { email = e } }]
}

# type = "ssh" is what makes Cloudflare offer in-browser terminal rendering
# for this hostname (dashboard-only toggle, not yet exposed by the provider
# — see infra/README.md for the one-time manual step and why).
resource "cloudflare_zero_trust_access_application" "console_ssh" {
  account_id = var.cloudflare_account_id
  name       = "Console — Browser SSH"
  type       = "ssh"
  domain     = var.console_hostname

  session_duration = "8h"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.console_ssh_allow.id
    precedence = 1
  }]
}

# Issues the CA that signs the short-lived SSH certificates Access hands
# authenticated browsers. Its public half has to be copied onto the Pi (see
# infra/README.md) so sshd knows to trust certs this CA signs.
resource "cloudflare_zero_trust_access_short_lived_certificate" "console_ssh" {
  account_id = var.cloudflare_account_id
  app_id     = cloudflare_zero_trust_access_application.console_ssh.id
}

# Public DNS for both hostnames, pointed at the tunnel (proxied — this is
# what lets the tunnel work without any port forwarding on the home router).
resource "cloudflare_dns_record" "pi_web" {
  zone_id = var.cloudflare_zone_id
  name    = var.web_hostname
  type    = "CNAME"
  content = "${var.tunnel_id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# Apex CNAME — Cloudflare flattens this at the DNS layer since it's proxied,
# so it's valid despite CNAMEs normally being disallowed at a zone apex.
resource "cloudflare_dns_record" "pi_apex" {
  zone_id = var.cloudflare_zone_id
  name    = var.apex_hostname
  type    = "CNAME"
  content = "${var.tunnel_id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# Also proxied to the tunnel (not a Cloudflare edge redirect) so it can be
# canonicalized to the apex by the Pi's nginx, the same way web-01 handles
# www.beyondthefirewall.me — see raspberrypistatic.conf.
resource "cloudflare_dns_record" "pi_www" {
  zone_id = var.cloudflare_zone_id
  name    = var.www_hostname
  type    = "CNAME"
  content = "${var.tunnel_id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# Null MX (RFC 7505): declares the apex refuses mail outright, so a
# sending server rejects immediately instead of retrying for days. The
# SPF/DMARC/DKIM records already in place (dashboard-managed, not here)
# tell receivers not to trust mail *from* this domain; this is the
# complement — telling senders not to bother delivering mail *to* it,
# since nothing here sends or receives email.
resource "cloudflare_dns_record" "pi_apex_null_mx" {
  zone_id  = var.cloudflare_zone_id
  name     = var.apex_hostname
  type     = "MX"
  content  = "."
  priority = 0
  proxied  = false
  ttl      = 1
}

resource "cloudflare_dns_record" "pi_ssh" {
  zone_id = var.cloudflare_zone_id
  name    = var.ssh_hostname
  type    = "CNAME"
  content = "${var.tunnel_id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# ssh_hostname is gated by Cloudflare Access: a person has to log in via
# the same email allowlist as the browser console (cloudflared opens a
# browser on first connect), and the GitHub Actions deploy authenticates
# with a dedicated service token instead. Key-only auth on the Pi's sshd is
# still the second layer behind this, and web_hostname stays open (it only
# serves the public site — and is redirected to the canonical domain, see
# redirects.tf).

# Machine identity for the deploy workflow. Its client_id/client_secret go
# into the CF_ACCESS_CLIENT_ID / CF_ACCESS_CLIENT_SECRET GitHub secrets (see
# infra/README.md). Expires after `duration` — rotate before expires_at
# (`terraform output deploy_service_token_expires_at`) or deploys start
# failing at the SSH step.
resource "cloudflare_zero_trust_access_service_token" "deploy" {
  account_id = var.cloudflare_account_id
  name       = "GitHub Actions deploy (beyondthefirewall)"
  duration   = "8760h"
}

resource "cloudflare_zero_trust_access_policy" "ssh_deploy_token" {
  account_id = var.cloudflare_account_id
  name       = "SSH — GitHub Actions deploy token"
  decision   = "non_identity"

  include = [{
    service_token = {
      token_id = cloudflare_zero_trust_access_service_token.deploy.id
    }
  }]
}

# Cloudflare only allows one Access application per hostname, and
# ssh_hostname already has one: infra/cloudflare/access.tf's "ssh_io"
# (imported by #17, predates this policy existing to add). So this project
# adds ssh_deploy_token to that application instead of creating a second
# one — infra/cloudflare/access.tf references this policy's ID by literal
# string (same cross-state pattern used for console_ssh_allow there), and
# this data source reads ssh_io's aud back for the tunnel ingress rule
# below, since that app isn't a resource in this state.
data "cloudflare_zero_trust_access_application" "ssh_io" {
  account_id = var.cloudflare_account_id
  app_id     = "1fb1bfb5-361c-42fd-b75a-3da05125799d"
}

# Edge-side SSH rate limiting used to live here as cloudflare_ruleset
# "ssh_rate_limit". It's now managed in infra/cloudflare/rulesets.tf
# instead, alongside the equivalent per-zone rate limiting for the other
# 6 domains — the live rule had already grown beyond "just SSH" (it also
# covers /members.html) before this move, so it fit the website-wide
# project better than this Pi-specific one.
#
# `removed` (not a plain deletion) so this project drops it from its own
# state without calling destroy on the live object — infra/cloudflare
# already imported that same ruleset ID as ratelimit["io"], so an actual
# destroy here would briefly drop live rate limiting until re-applied
# there. This block can be deleted once this project's state no longer
# has the resource (i.e. after the first apply following this change).
removed {
  from = cloudflare_ruleset.ssh_rate_limit

  lifecycle {
    destroy = false
  }
}
