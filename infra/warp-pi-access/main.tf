terraform {
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
        hostname = var.ssh_hostname
        service  = "ssh://localhost:22"
      },
      {
        service = "http_status:404"
      },
    ]
  }
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

resource "cloudflare_dns_record" "pi_ssh" {
  zone_id = var.cloudflare_zone_id
  name    = var.ssh_hostname
  type    = "CNAME"
  content = "${var.tunnel_id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# No Access application/policy in front of either hostname — deliberately
# open to the internet. Web is low-risk; SSH is a real raw sshd exposed
# publicly, so it depends on key-only auth (no password auth) on the Pi
# itself as the actual security boundary now that Access isn't gating it.
#
# The WARP posture check and both Access policies/applications that used to
# gate this were removed here. The manually-created "Warp" posture check
# (Zero Trust > Reusable components > Posture checks) still exists in
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
    description = "Rate limit pi-ssh connection attempts"
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
