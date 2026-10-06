# Reusable Access policies --------------------------------------------------
#
# "Console SSH — allowed members" (a63b54db-…) intentionally not here —
# infra/warp-pi-access/main.tf already manages it as console_ssh_allow.

resource "cloudflare_zero_trust_access_policy" "members_area" {
  account_id = local.account_id
  name       = "Members Area"
  decision   = "allow"
  include = [
    # stewart.andrews@gmail.com and 699700@proton.me removed — both
    # accounts were confirmed deleted; see infra/README.md history.
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
    # Tightened from an IP allow-rule (82.163.151.25/32) to the same
    # two-email allowlist as members_area — "only two users should have
    # any access" (Stew, 2026-10-06). An IP rule grants any device on that
    # network, not a specific person.
    { email = { email = "stewart699700@icloud.com" } },
    { email = { email = "sandrews@natilik.com" } },
  ]
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
  # References both policies by literal ID since they're owned by
  # infra/warp-pi-access/main.tf (a separate Terraform state) — can't be a
  # resource reference across projects. "SSH — GitHub Actions deploy
  # token" (ssh_deploy_token) was added alongside the deploy service
  # token rather than a second Access application on this hostname —
  # Cloudflare only allows one per hostname.
  policies = [
    { id = "a63b54db-b556-449d-87f7-51c21894ca34", precedence = 1 },
    { id = "fa21dc2b-4083-491a-847c-3a75de1e37cf", precedence = 2 },
  ]
}

# "Console — Browser SSH" (f4053001-…) intentionally not here —
# infra/warp-pi-access/main.tf already manages it as console_ssh.

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
  to = cloudflare_zero_trust_access_application.members_area
  id = "accounts/${local.account_id}/fb91529a-f42c-4e17-95ad-683cfed2bc20"
}

# Not managed here: "Warp Login App" (5b0ed2c5-…, WARP enrolment app tied to Zero
# Trust device settings), Gateway rule "Block Malware", device profiles.
