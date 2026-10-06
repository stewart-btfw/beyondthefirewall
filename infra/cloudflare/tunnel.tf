resource "cloudflare_zero_trust_tunnel_cloudflared" "btfw" {
  account_id = local.account_id
  name       = "BTFW"
  config_src = "cloudflare"
}

import {
  to = cloudflare_zero_trust_tunnel_cloudflared.btfw
  id = "${local.account_id}/${local.tunnel_id}"
}

# The tunnel's ingress config (cloudflare_zero_trust_tunnel_cloudflared_config)
# intentionally not here — infra/warp-pi-access/main.tf already manages it,
# including every hostname routed through this tunnel. This file only adopts
# the tunnel's own identity (name, config_src), which nothing managed before.
