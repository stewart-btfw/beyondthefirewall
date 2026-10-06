# All records: TTL Auto (1). Tunnel CNAMEs are proxied; everything else DNS-only.
# DMARC rua addresses were added by Cloudflare DMARC Management - keep them.
locals {
  dns_records = {
    app_cname_apex      = { zone = "app", name = "beyondthefirewall.app", type = "CNAME", content = local.tunnel_cname, proxied = true, id = "16ee35a82144e23f05a8f893df70f6f4" }
    app_cname_www       = { zone = "app", name = "www.beyondthefirewall.app", type = "CNAME", content = local.tunnel_cname, proxied = true, id = "141c5a54b165df9a1224c422e3a85deb" }
    app_mx_null         = { zone = "app", name = "beyondthefirewall.app", type = "MX", content = ".", proxied = false, priority = 0, id = "2865373fc07521199bc69a6331b82ae8" }
    app_txt_google      = { zone = "app", name = "beyondthefirewall.app", type = "TXT", content = "\"google-site-verification=-J2vbwxzOvgaMrbXcZb_NtZ64GGBQTDWwfQ1z8LeGM4\"", proxied = false, id = "1b30cdb12967201790af57f095a1d110" }
    app_txt_spf         = { zone = "app", name = "beyondthefirewall.app", type = "TXT", content = "\"v=spf1 -all\"", proxied = false, id = "e104b767184693da6df6c41abca789c2" }
    app_txt_dmarc       = { zone = "app", name = "_dmarc.beyondthefirewall.app", type = "TXT", content = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:b3f7ec3471b14131bda920dac8a3888a@dmarc-reports.cloudflare.net;\"", proxied = false, id = "fdf640e502f0d67a10dba793df124158" }
    app_txt_dkim_null   = { zone = "app", name = "*._domainkey.beyondthefirewall.app", type = "TXT", content = "\"v=DKIM1; p=\"", proxied = false, id = "a36fac3c883d04629d2bc50e1ce9e846" }
    co_uk_cname_apex    = { zone = "co_uk", name = "beyondthefirewall.co.uk", type = "CNAME", content = local.tunnel_cname, proxied = true, id = "1f9ebc86ca723c85390e821fe42ab363" }
    co_uk_cname_www     = { zone = "co_uk", name = "www.beyondthefirewall.co.uk", type = "CNAME", content = local.tunnel_cname, proxied = true, id = "eaf240a69d0c59c28a7eb48fac3467d3" }
    co_uk_mx_null       = { zone = "co_uk", name = "beyondthefirewall.co.uk", type = "MX", content = ".", proxied = false, priority = 0, id = "469321d258777c8290d426ad03c7a575" }
    co_uk_txt_google    = { zone = "co_uk", name = "beyondthefirewall.co.uk", type = "TXT", content = "\"google-site-verification=e1PdjaXpfa48oO-H3kyapnJYfOmbVmSy7tW2vknwybg\"", proxied = false, id = "fa21cc3d53a42f2abd7592b3c287f3d8" }
    co_uk_txt_spf       = { zone = "co_uk", name = "beyondthefirewall.co.uk", type = "TXT", content = "\"v=spf1 -all\"", proxied = false, id = "8f2c722a5957cf8eb8b3ce7b4a75102b" }
    co_uk_txt_dmarc     = { zone = "co_uk", name = "_dmarc.beyondthefirewall.co.uk", type = "TXT", content = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:05da3bad142a48b3b0bda32998e03c54@dmarc-reports.cloudflare.net;\"", proxied = false, id = "9ce6d685db7a88b273cd32c96f8933d6" }
    co_uk_txt_dkim_null = { zone = "co_uk", name = "*._domainkey.beyondthefirewall.co.uk", type = "TXT", content = "\"v=DKIM1; p=\"", proxied = false, id = "45613af4b7b93eca86399c03a2a3890b" }
    info_cname_apex     = { zone = "info", name = "beyondthefirewall.info", type = "CNAME", content = local.tunnel_cname, proxied = true, id = "f3ea8996c58f858b3e849a5f74b5b8a2" }
    info_cname_www      = { zone = "info", name = "www.beyondthefirewall.info", type = "CNAME", content = local.tunnel_cname, proxied = true, id = "c8eb09b73624e3a26171fc156be55b73" }
    info_mx_null        = { zone = "info", name = "beyondthefirewall.info", type = "MX", content = ".", proxied = false, priority = 0, id = "122e27112c3983a08ecfc20453e3cb32" }
    info_txt_google     = { zone = "info", name = "beyondthefirewall.info", type = "TXT", content = "\"google-site-verification=2QB1jQrfc30XssLnJ_t2TUWPtwgIzhCn84SyxmjVfr4\"", proxied = false, id = "447763d98ae36b03dd11fd2ba5bd2214" }
    info_txt_spf        = { zone = "info", name = "beyondthefirewall.info", type = "TXT", content = "\"v=spf1 -all\"", proxied = false, id = "e1b1484d8289114c69fe862a138dfc21" }
    info_txt_dmarc      = { zone = "info", name = "_dmarc.beyondthefirewall.info", type = "TXT", content = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:c095a29f90d84739b7625eb78f709e61@dmarc-reports.cloudflare.net;\"", proxied = false, id = "adaeab1c2b8f315b2fb06af2b1681bf0" }
    info_txt_dkim_null  = { zone = "info", name = "*._domainkey.beyondthefirewall.info", type = "TXT", content = "\"v=DKIM1; p=\"", proxied = false, id = "a45dc8b146a7c905ddb3381a0c275759" }
    # io_cname_apex, io_cname_ssh, io_cname_web, io_cname_www, io_mx_null
    # intentionally not here — infra/warp-pi-access/main.tf already manages
    # these 5 as pi_apex/pi_ssh/pi_web/pi_www/pi_apex_null_mx.
    io_txt_google     = { zone = "io", name = "beyondthefirewall.io", type = "TXT", content = "\"google-site-verification=8UyXLg9eubpqhtjvbBFSAU3eRwixbMLr4OXzN-p0Rkk\"", proxied = false, id = "3a1542d8041bb22a147ebba8800dcb5e" }
    io_txt_spf        = { zone = "io", name = "beyondthefirewall.io", type = "TXT", content = "\"v=spf1 -all\"", proxied = false, id = "c6f19846908b6caa3d1294394c76df96" }
    io_txt_dmarc      = { zone = "io", name = "_dmarc.beyondthefirewall.io", type = "TXT", content = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:881bce5765064fd9be6396acb0272200@dmarc-reports.cloudflare.net;\"", proxied = false, id = "94a4e61992271d153b527a8e67f53489" }
    io_txt_dkim_null  = { zone = "io", name = "*._domainkey.beyondthefirewall.io", type = "TXT", content = "\"v=DKIM1; p=\"", proxied = false, id = "2c9aa87698308f435ede612914ca7012" }
    me_cname_apex     = { zone = "me", name = "beyondthefirewall.me", type = "CNAME", content = local.tunnel_cname, proxied = true, id = "6290cdf8e56f03dba8922e77239329e2" }
    me_cname_console  = { zone = "me", name = "console.beyondthefirewall.me", type = "CNAME", content = local.tunnel_cname, proxied = true, id = "f76c73770d2986fe05890ac03ff75786" }
    me_cname_www      = { zone = "me", name = "www.beyondthefirewall.me", type = "CNAME", content = local.tunnel_cname, proxied = true, id = "f6ecb4298b0ebec755b49763c872c399" }
    me_mx_null        = { zone = "me", name = "beyondthefirewall.me", type = "MX", content = ".", proxied = false, priority = 0, id = "baaec87211677f67bfa7a8d236eb600c" }
    me_txt_google     = { zone = "me", name = "beyondthefirewall.me", type = "TXT", content = "\"google-site-verification=DKVtqehc-apr0765DZXhpLBiJvOJnkCrFZlAgM4tgyM\"", proxied = false, id = "e53e2ad38677e7695e304ac6f2f42f1e" }
    me_txt_spf        = { zone = "me", name = "beyondthefirewall.me", type = "TXT", content = "\"v=spf1 -all\"", proxied = false, id = "1815f501653cf7bad9ca9bc8b8c5164e" }
    me_txt_dmarc      = { zone = "me", name = "_dmarc.beyondthefirewall.me", type = "TXT", content = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:26583bd84f4a4f2881e8d156b9995668@dmarc-reports.cloudflare.net;\"", proxied = false, id = "e2851ae8bf73a267ba88ca396a9abae2" }
    me_txt_dkim_null  = { zone = "me", name = "*._domainkey.beyondthefirewall.me", type = "TXT", content = "\"v=DKIM1; p=\"", proxied = false, id = "8644f27673fd11d8f5b0286d745118f8" }
    org_cname_apex    = { zone = "org", name = "beyondthefirewall.org", type = "CNAME", content = local.tunnel_cname, proxied = true, id = "197c9664287347ce324da51d8f3ef12b" }
    org_cname_www     = { zone = "org", name = "www.beyondthefirewall.org", type = "CNAME", content = local.tunnel_cname, proxied = true, id = "f3381db1b5c5f967827e5bc28317b479" }
    org_mx_null       = { zone = "org", name = "beyondthefirewall.org", type = "MX", content = ".", proxied = false, priority = 0, id = "f9593ec42910f3280ffaeb072254b1a1" }
    org_txt_google    = { zone = "org", name = "beyondthefirewall.org", type = "TXT", content = "\"google-site-verification=GH-JNWE9CmoF0ZGEDN7bKDKxhq1CNdrHZhls3_2gniE\"", proxied = false, id = "9c6e5a84abd88d029323136f25479626" }
    org_txt_spf       = { zone = "org", name = "beyondthefirewall.org", type = "TXT", content = "\"v=spf1 -all\"", proxied = false, id = "b0b54f9499a40774f539b1793b794363" }
    org_txt_dmarc     = { zone = "org", name = "_dmarc.beyondthefirewall.org", type = "TXT", content = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:efe9667a2bd24a7b905b015af71fdbee@dmarc-reports.cloudflare.net;\"", proxied = false, id = "c1f0c389aabbe0e010fdb0365dc26090" }
    org_txt_dkim_null = { zone = "org", name = "*._domainkey.beyondthefirewall.org", type = "TXT", content = "\"v=DKIM1; p=\"", proxied = false, id = "18732727dc39a5d18ccefca9f476d753" }
    uk_cname_apex     = { zone = "uk", name = "beyondthefirewall.uk", type = "CNAME", content = local.tunnel_cname, proxied = true, id = "21568077855a59e1b7b1c8c3148fa867" }
    uk_cname_www      = { zone = "uk", name = "www.beyondthefirewall.uk", type = "CNAME", content = local.tunnel_cname, proxied = true, id = "ea7ed2b5934aea563530bb0de0cd0ebe" }
    uk_mx_null        = { zone = "uk", name = "beyondthefirewall.uk", type = "MX", content = ".", proxied = false, priority = 0, id = "315818c1a73bb978692607c1d8cd2608" }
    uk_txt_google     = { zone = "uk", name = "beyondthefirewall.uk", type = "TXT", content = "\"google-site-verification=O2wrGd94XCbWyrKn_jyvDq53IjNKwkYHIGSyYLGnT_o\"", proxied = false, id = "d983d1f593ace626fcbade260c23b70f" }
    uk_txt_spf        = { zone = "uk", name = "beyondthefirewall.uk", type = "TXT", content = "\"v=spf1 -all\"", proxied = false, id = "9b3a68900658b31f44633c9b79a1f089" }
    uk_txt_dmarc      = { zone = "uk", name = "_dmarc.beyondthefirewall.uk", type = "TXT", content = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:a2a6e37047144866b36a40c719dfe490@dmarc-reports.cloudflare.net;\"", proxied = false, id = "534fcd8a395731c508636822f12b058c" }
    uk_txt_dkim_null  = { zone = "uk", name = "*._domainkey.beyondthefirewall.uk", type = "TXT", content = "\"v=DKIM1; p=\"", proxied = false, id = "c4633de8e42ecc456f53430d26c647f4" }
  }
}

resource "cloudflare_dns_record" "this" {
  for_each = local.dns_records

  zone_id  = local.zones[each.value.zone].id
  name     = each.value.name
  type     = each.value.type
  content  = each.value.content
  proxied  = each.value.proxied
  priority = try(each.value.priority, null)
  ttl      = 1
}

import {
  for_each = local.dns_records
  to       = cloudflare_dns_record.this[each.key]
  id       = "${local.zones[each.value.zone].id}/${each.value.id}"
}
