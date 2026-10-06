resource "cloudflare_zero_trust_tunnel_cloudflared" "btfw" {
  account_id = local.account_id
  name       = "BTFW"
  config_src = "cloudflare"
}

import {
  to = cloudflare_zero_trust_tunnel_cloudflared.btfw
  id = "${local.account_id}/${local.tunnel_id}"
}

# Order matters: cloudflared matches top to bottom; catch-all must be last.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "btfw" {
  account_id = local.account_id
  tunnel_id  = local.tunnel_id

  config = {
    ingress = [
      { hostname = "web.beyondthefirewall.io", service = "http://localhost:80" },
      { hostname = "beyondthefirewall.io", service = "http://localhost:80" },
      { hostname = "www.beyondthefirewall.io", service = "http://localhost:80" },
      { hostname = "ssh.beyondthefirewall.io", service = "ssh://localhost:22" },
      { hostname = "beyondthefirewall.me", service = "http://localhost:80" },
      { hostname = "www.beyondthefirewall.me", service = "http://localhost:80" },
      { hostname = "beyondthefirewall.org", service = "http://localhost:80" },
      { hostname = "www.beyondthefirewall.org", service = "http://localhost:80" },
      { hostname = "beyondthefirewall.app", service = "http://localhost:80" },
      { hostname = "www.beyondthefirewall.app", service = "http://localhost:80" },
      { hostname = "beyondthefirewall.co.uk", service = "http://localhost:80" },
      { hostname = "www.beyondthefirewall.co.uk", service = "http://localhost:80" },
      { hostname = "beyondthefirewall.info", service = "http://localhost:80" },
      { hostname = "www.beyondthefirewall.info", service = "http://localhost:80" },
      { hostname = "beyondthefirewall.uk", service = "http://localhost:80" },
      { hostname = "www.beyondthefirewall.uk", service = "http://localhost:80" },
      {
        hostname = "console.beyondthefirewall.me"
        service  = "ssh://localhost:22"
        origin_request = {
          access = {
            required  = true
            team_name = "beyondthefirewall"
            aud_tag   = [cloudflare_zero_trust_access_application.console_ssh.aud]
          }
        }
      },
      { service = "http_status:404" },
    ]
    warp_routing = { enabled = true }
  }
}

import {
  to = cloudflare_zero_trust_tunnel_cloudflared_config.btfw
  id = "${local.account_id}/${local.tunnel_id}"
}
