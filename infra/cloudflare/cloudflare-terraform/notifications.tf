resource "cloudflare_notification_policy" "tunnel_health" {
  account_id = local.account_id
  name       = "Tunnel health — BTFW"
  alert_type = "tunnel_health_event"
  enabled    = true
  mechanisms = {
    email = [{ id = var.alert_email }]
  }
}

import {
  to = cloudflare_notification_policy.tunnel_health
  id = "${local.account_id}/2fadc472e95343ca972294f28adcbded"
}

variable "alert_email" {
  description = "Address that receives Cloudflare alerts"
  type        = string
  default     = "cloudflare.kwrcs@passmail.net"
}
