# Canonical-domain redirects (Cloudflare Bulk Redirects, account-level).
#
# All seven domains route to the same Pi, so without this every page exists
# at ~15 hostnames. This 301s every non-canonical site hostname to
# var.canonical_domain at Cloudflare's edge — before Access or the tunnel —
# keeping the path and query string. Being account-level, one list covers
# every zone, including the six whose DNS isn't managed here.
#
# Deliberately NOT redirected: ssh_hostname and console_hostname (SSH over
# the tunnel, not web pages), and the canonical apex itself.

locals {
  # Every site hostname except the canonical apex itself.
  redirect_sources = setsubtract(
    concat(
      [var.apex_hostname, var.www_hostname, var.web_hostname],
      flatten([for d in var.extra_site_domains : [d, "www.${d}"]]),
    ),
    [var.canonical_domain],
  )
}

resource "cloudflare_list" "canonical_redirects" {
  account_id  = var.cloudflare_account_id
  name        = "canonical_redirects"
  description = "Non-canonical site hostnames -> https://${var.canonical_domain}"
  kind        = "redirect"
}

resource "cloudflare_list_item" "canonical_redirects" {
  for_each = local.redirect_sources

  account_id = var.cloudflare_account_id
  list_id    = cloudflare_list.canonical_redirects.id

  redirect = {
    source_url            = "${each.value}/"
    target_url            = "https://${var.canonical_domain}/"
    status_code           = 301
    include_subdomains    = false
    subpath_matching      = true
    preserve_path_suffix  = true
    preserve_query_string = true
  }
}

# There can be only one account-level root ruleset per phase. If `apply`
# fails because one already exists (e.g. a Bulk Redirect rule made in the
# dashboard), import it instead:
#   terraform import cloudflare_ruleset.canonical_redirects accounts/<account_id>/<ruleset_id>
resource "cloudflare_ruleset" "canonical_redirects" {
  account_id  = var.cloudflare_account_id
  name        = "Canonical domain redirects"
  description = "301 every non-canonical site hostname to ${var.canonical_domain}"
  kind        = "root"
  phase       = "http_request_redirect"

  rules = [{
    description = "Redirect to ${var.canonical_domain}"
    expression  = format("http.request.full_uri in $%s", cloudflare_list.canonical_redirects.name)
    action      = "redirect"
    enabled     = true

    action_parameters = {
      from_list = {
        name = cloudflare_list.canonical_redirects.name
        key  = "http.request.full_uri"
      }
    }
  }]
}
