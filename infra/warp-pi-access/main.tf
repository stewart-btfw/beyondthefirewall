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

# Routes both hostnames through the existing tunnel to services on the Pi.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "pi" {
  account_id = var.cloudflare_account_id
  tunnel_id  = var.tunnel_id
  source     = "cloudflare"

  config = {
    ingress = [
      {
        hostname = var.web_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.apex_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.www_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.ssh_hostname
        service  = "ssh://localhost:22"
      },
      {
        hostname = var.me_apex_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.me_www_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.org_apex_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.org_www_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.app_apex_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.app_www_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.co_uk_apex_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.co_uk_www_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.info_apex_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.info_www_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.uk_apex_hostname
        service  = "http://localhost:${var.web_port}"
      },
      {
        hostname = var.uk_www_hostname
        service  = "http://localhost:${var.web_port}"
      },
      # Browser-rendered SSH console. Unlike every other ingress rule above,
      # this one requires Access authorization at the tunnel itself — the
      # connection never reaches the Pi's sshd unless it already carries a
      # valid token for cloudflare_zero_trust_access_application.console_ssh.
      {
        hostname = var.console_hostname
        service  = "ssh://localhost:22"

        origin_request = {
          access = {
            required  = true
            team_name = var.cloudflare_team_name
            aud_tag   = [cloudflare_zero_trust_access_application.console_ssh.aud]
          }
        }
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

# Lets members log in as var.console_ssh_username (the Pi's one real user)
# via the short-lived SSH certificates Access issues them, without needing
# an individual Unix account per allowed email.
resource "cloudflare_zero_trust_access_policy" "console_ssh_allow" {
  account_id = var.cloudflare_account_id
  name       = "Console SSH — allowed members"
  decision   = "allow"

  include = [for e in var.console_allowed_emails : { email = { email = e } }]

  connection_rules = {
    ssh = {
      usernames         = [var.console_ssh_username]
      allow_email_alias = false
    }
  }
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

resource "cloudflare_dns_record" "pi_ssh" {
  zone_id = var.cloudflare_zone_id
  name    = var.ssh_hostname
  type    = "CNAME"
  content = "${var.tunnel_id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# No Access application/policy in front of web_hostname or ssh_hostname —
# deliberately open to the internet. Web is low-risk; SSH is a real raw
# sshd exposed publicly, so it depends on key-only auth (no password auth)
# on the Pi itself as the actual security boundary now that Access isn't
# gating it. (console_hostname above is the exception — that one *is*
# Access-gated, specifically so Cloudflare can render an authenticated
# browser SSH terminal there; it doesn't change anything about this pair.)
#
# The WARP posture check and both Access policies/applications that used to
# gate ssh_hostname were removed here. The manually-created "Warp" posture
# check (Zero Trust > Reusable components > Posture checks) still exists in
# Cloudflare if this ever needs to be re-gated later.

# Edge-side rate limiting on SSH connection attempts. fail2ban on the Pi
# itself can't work here — sshd only ever sees 127.0.0.1 as the source,
# since Cloudflare Tunnel proxies every connection through localhost. This
# runs at Cloudflare's edge instead, where the real source IP is still
# visible. action = "block" (not "challenge") since an SSH client can't
# solve a browser challenge.
resource "cloudflare_ruleset" "ssh_rate_limit" {
  zone_id     = var.cloudflare_zone_id
  name        = "SSH connection rate limit"
  description = "Block IPs making excessive connection attempts to the Pi's SSH tunnel hostname"
  phase       = "http_ratelimit"
  kind        = "zone"

  rules = [{
    description = "Rate limit ssh connection attempts"
    expression  = "(http.host eq \"${var.ssh_hostname}\")"
    action      = "block"

    # Free zone plan is restricted to a 10s period and 10s mitigation_timeout
    # (larger values return "not entitled" 400s), so an offending IP gets
    # re-evaluated every 10s rather than a single longer block.
    ratelimit = {
      characteristics     = ["ip.src", "cf.colo.id"]
      period              = 10
      requests_per_period = 2
      mitigation_timeout  = 10
    }
  }]
}
