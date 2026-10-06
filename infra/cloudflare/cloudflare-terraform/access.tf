# Reusable Access policies --------------------------------------------------

resource "cloudflare_zero_trust_access_policy" "console_ssh" {
  account_id       = local.account_id
  name             = "Console SSH — allowed members"
  decision         = "allow"
  session_duration = "8h"
  include = [
    { email = { email = "sandrews@natilik.com" } },
    { email = { email = "stewart699700@icloud.com" } },
  ]
}

resource "cloudflare_zero_trust_access_policy" "members_area" {
  account_id = local.account_id
  name       = "Members Area"
  decision   = "allow"
  include = [
    { email = { email = "stewart.andrews@gmail.com" } },
    { email = { email = "699700@proton.me" } },
    { email = { email = "stewart699700@icloud.com" } },
    { email = { email = "sandrews@natilik.com" } },
  ]
}

resource "cloudflare_zero_trust_access_policy" "warp_enrolment" {
  account_id       = local.account_id
  name             = "BeyondTheFirewall"
  decision         = "allow"
  session_duration = "24h"
  include = [
    { ip = { ip = "82.163.151.25/32" } },
  ]
}

import {
  to = cloudflare_zero_trust_access_policy.console_ssh
  id = "${local.account_id}/a63b54db-b556-449d-87f7-51c21894ca34"
}
import {
  to = cloudflare_zero_trust_access_policy.members_area
  id = "${local.account_id}/425964e8-6b24-44d5-9d18-e2cc02694980"
}
import {
  to = cloudflare_zero_trust_access_policy.warp_enrolment
  id = "${local.account_id}/f0a5baba-0cf7-41c6-aa83-b9d1794e2bd3"
}

# Access applications -------------------------------------------------------

resource "cloudflare_zero_trust_access_application" "ssh_io" {
  account_id                 = local.account_id
  name                       = "SSH — beyondthefirewall.io"
  type                       = "self_hosted"
  domain                     = "ssh.beyondthefirewall.io"
  destinations               = [{ type = "public", uri = "ssh.beyondthefirewall.io" }]
  session_duration           = "8h"
  app_launcher_visible       = false
  http_only_cookie_attribute = true
  policies                   = [{ id = cloudflare_zero_trust_access_policy.console_ssh.id, precedence = 1 }]
}

resource "cloudflare_zero_trust_access_application" "console_ssh" {
  account_id                 = local.account_id
  name                       = "Console — Browser SSH"
  type                       = "ssh"
  domain                     = "console.beyondthefirewall.me"
  destinations               = [{ type = "public", uri = "console.beyondthefirewall.me" }]
  session_duration           = "8h"
  app_launcher_visible       = true
  http_only_cookie_attribute = true
  policies                   = [{ id = cloudflare_zero_trust_access_policy.console_ssh.id, precedence = 1 }]
}

resource "cloudflare_zero_trust_access_application" "members_area" {
  account_id                 = local.account_id
  name                       = "Members Area"
  type                       = "self_hosted"
  domain                     = "beyondthefirewall.me/members.html"
  destinations               = [for k in ["me", "org", "uk", "info", "co_uk", "app", "io"] : { type = "public", uri = "${local.zones[k].name}/members.html" }]
  session_duration           = "24h"
  app_launcher_visible       = true
  http_only_cookie_attribute = true
  policies                   = [{ id = cloudflare_zero_trust_access_policy.members_area.id, precedence = 1 }]
}

import {
  to = cloudflare_zero_trust_access_application.ssh_io
  id = "accounts/${local.account_id}/1fb1bfb5-361c-42fd-b75a-3da05125799d"
}
import {
  to = cloudflare_zero_trust_access_application.console_ssh
  id = "accounts/${local.account_id}/f4053001-5195-452c-bfcd-b0b1d502ddb1"
}
import {
  to = cloudflare_zero_trust_access_application.members_area
  id = "accounts/${local.account_id}/fb91529a-f42c-4e17-95ad-683cfed2bc20"
}

# Not managed here: "Warp Login App" (5b0ed2c5-…, WARP enrolment app tied to Zero
# Trust device settings), Gateway rule "Block Malware", device profiles.
