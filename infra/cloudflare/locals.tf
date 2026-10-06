locals {
  account_id   = "2314a9913a2e9dadad8bb6d1625aa17b"
  tunnel_id    = "4f0e31e4-3ada-4182-b057-48153417d481"
  tunnel_cname = "${local.tunnel_id}.cfargotunnel.com"

  zones = {
    app   = { name = "beyondthefirewall.app", id = "106f4e63497e9575009dd02c07dc8469" }
    co_uk = { name = "beyondthefirewall.co.uk", id = "743d5d531e0e73a8c11aa7ac4bf5eda4" }
    info  = { name = "beyondthefirewall.info", id = "86d0eb67b82436906809d215c2625146" }
    io    = { name = "beyondthefirewall.io", id = "98528201d83d6d272edb65192795677c" }
    me    = { name = "beyondthefirewall.me", id = "943c2aef23843537ad1a3892970b1501" }
    org   = { name = "beyondthefirewall.org", id = "0925e07c6497f5992593989f797ded1e" }
    uk    = { name = "beyondthefirewall.uk", id = "358f741b135bd5392d4bf48f920f0e85" }
  }
}
