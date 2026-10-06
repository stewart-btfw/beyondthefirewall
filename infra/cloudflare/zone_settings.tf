# Identical on all 7 zones.
locals {
  zone_settings = {
    ssl                      = "strict"
    min_tls_version          = "1.2"
    tls_1_3                  = "on"
    always_use_https         = "on"
    automatic_https_rewrites = "on"
    opportunistic_encryption = "on"
    http3                    = "on"
    "0rtt"                   = "off"
    brotli                   = "on"
    early_hints              = "on"
    ech                      = "on"
    security_level           = "medium"
    browser_check            = "on"
    email_obfuscation        = "on"
  }

  zone_setting_pairs = {
    for pair in setproduct(keys(local.zones), keys(local.zone_settings)) :
    "${pair[0]}/${pair[1]}" => { zone = pair[0], setting = pair[1], value = local.zone_settings[pair[1]] }
  }
}

resource "cloudflare_zone_setting" "this" {
  for_each   = local.zone_setting_pairs
  zone_id    = local.zones[each.value.zone].id
  setting_id = each.value.setting
  value      = each.value.value
}

import {
  for_each = local.zone_setting_pairs
  to       = cloudflare_zone_setting.this[each.key]
  id       = "${local.zones[each.value.zone].id}/${each.value.setting}"
}

# HSTS: 1 year, includeSubDomains, preload, nosniff on. hstspreload.org
# requires max_age >= 31536000 (1 year) alongside includeSubDomains and
# preload before it will accept a submission.
resource "cloudflare_zone_setting" "security_header" {
  for_each   = local.zones
  zone_id    = each.value.id
  setting_id = "security_header"
  value = {
    strict_transport_security = {
      enabled            = true
      max_age            = 31536000
      include_subdomains = true
      preload            = true
      nosniff            = true
    }
  }
}

import {
  for_each = local.zones
  to       = cloudflare_zone_setting.security_header[each.key]
  id       = "${each.value.id}/security_header"
}

resource "cloudflare_zone_dnssec" "this" {
  for_each = local.zones
  zone_id  = each.value.id
  status   = "active"
}

import {
  for_each = local.zones
  to       = cloudflare_zone_dnssec.this[each.key]
  id       = each.value.id
}

resource "cloudflare_bot_management" "this" {
  for_each           = local.zones
  zone_id            = each.value.id
  enable_js          = true
  fight_mode         = false
  ai_bots_protection = "block"
  crawler_protection = "enabled"
}

import {
  for_each = local.zones
  to       = cloudflare_bot_management.this[each.key]
  id       = each.value.id
}
