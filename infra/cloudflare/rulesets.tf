locals {
  ruleset_ids = {
    app   = { ratelimit = "63f6d35cd83042508e3949b897f81e38", waf = "f40cc990f0704896815238a8a9e70776", headers = "536e7b6b5e734771b76982de66a55803" }
    co_uk = { ratelimit = "1266f0b4444347b6b1d30f9ceeaa859c", waf = "f1987cefaa2f42f68ef1b06df72e5c05", headers = "23b7b0c596a046ae848028c52674fa11" }
    info  = { ratelimit = "189099e8cce14ceebb21a3e009855abd", waf = "0bcc17018f2f4deea9aa098ada6d49a5", headers = "9bf09e89a34d49c2854f3658f89f21d5" }
    io    = { ratelimit = "b2904aa6c7d6470989de0d969ee01385", waf = "2fa5935b7f2c4cdc85214156e05621ae", headers = "7749222bf7014bddb605dad9d3d85bd8" }
    me    = { ratelimit = "026832b1153646c7a3a27182ee489f1c", waf = "87ab08e3eca24a0e8ed3c8b0df55d919", headers = "5ea602756209491f851a72cf6bf43521" }
    org   = { ratelimit = "106e06f8331c48af9c74e49b9a2dce0d", waf = "44e7caad523b44e18a620e0fc7d20cf3", headers = "cb4347c4343744da9a34c596d84b1b62" }
    uk    = { ratelimit = "d8a2e9c495604738a780ebf0070c801d", waf = "5cdbf5c50daa454e96116f8cf5470493", headers = "0c28804fcd4d4b20875d11e2fef3e067" }
  }

  # Hostnames that get the security headers (website hosts only - not ssh/console).
  header_hosts = {
    for k, z in local.zones : k => concat([z.name, "www.${z.name}"], k == "io" ? ["web.beyondthefirewall.io"] : [])
  }
}

# --- WAF custom rules (same on every zone)
resource "cloudflare_ruleset" "waf_custom" {
  for_each = local.zones
  zone_id  = each.value.id
  name     = "default"
  kind     = "zone"
  phase    = "http_request_firewall_custom"

  rules = [{
    description = "Block CMS/PHP scanner probes"
    expression  = "(http.request.uri.path contains \"wp-login\") or (http.request.uri.path contains \"wp-admin\") or (http.request.uri.path contains \"xmlrpc.php\") or (ends_with(http.request.uri.path, \".php\"))"
    action      = "block"
    enabled     = true
  }]
}

import {
  for_each = local.zones
  to       = cloudflare_ruleset.waf_custom[each.key]
  id       = "zones/${each.value.id}/${local.ruleset_ids[each.key].waf}"
}

# --- Rate limiting (Free plan: 1 rule per zone, 10s period / 10s timeout)
resource "cloudflare_ruleset" "ratelimit" {
  for_each = local.zones
  zone_id  = each.value.id
  name     = each.key == "io" ? "SSH connection rate limit" : "default"
  kind     = "zone"
  phase    = "http_ratelimit"

  rules = [{
    description = each.key == "io" ? "Rate limit SSH and members page" : "Rate limit members page"
    expression  = each.key == "io" ? "(http.host eq \"ssh.beyondthefirewall.io\") or (http.request.uri.path eq \"/members.html\")" : "(http.request.uri.path eq \"/members.html\")"
    action      = "block"
    enabled     = true
    ratelimit = {
      characteristics     = ["ip.src", "cf.colo.id"]
      period              = 10
      requests_per_period = 5
      mitigation_timeout  = 10
    }
  }]
}

import {
  for_each = local.zones
  to       = cloudflare_ruleset.ratelimit[each.key]
  id       = "zones/${each.value.id}/${local.ruleset_ids[each.key].ratelimit}"
}

# --- Security response headers
resource "cloudflare_ruleset" "security_headers" {
  for_each = local.zones
  zone_id  = each.value.id
  name     = "default"
  kind     = "zone"
  phase    = "http_response_headers_transform"

  rules = [{
    description = "Security headers"
    expression  = "(http.host in {${join(" ", [for h in local.header_hosts[each.key] : "\"${h}\""])}})"
    action      = "rewrite"
    enabled     = true
    action_parameters = {
      headers = {
        "Referrer-Policy"    = { operation = "set", value = "strict-origin-when-cross-origin" }
        "X-Frame-Options"    = { operation = "set", value = "SAMEORIGIN" }
        "Permissions-Policy" = { operation = "set", value = "camera=(), microphone=(), geolocation=(), payment=(), usb=()" }
      }
    }
  }]
}

import {
  for_each = local.zones
  to       = cloudflare_ruleset.security_headers[each.key]
  id       = "zones/${each.value.id}/${local.ruleset_ids[each.key].headers}"
}
