terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Uploads Prisma Access Browser's tenant root CA (downloaded from Strata
# Cloud Manager: Administration > Integrations > "Prisma Access Certificate")
# so Cloudflare can validate the per-browser client certificates Prisma
# Access Browser's own PKI auto-issues and auto-renews. There is no private
# key to manage here — Prisma Access holds the CA key, and each browser's
# client cert lives only in that browser's TPM/Keychain.
resource "cloudflare_mtls_certificate" "prisma_access_ca" {
  account_id   = var.cloudflare_account_id
  name         = "prisma-access-browser-ca"
  certificates = file(var.ca_cert_path)
  ca           = true
}

# Tells Cloudflare's edge to request/validate a client cert (against the CA
# above) during the TLS handshake for this hostname.
resource "cloudflare_certificate_authorities_hostname_associations" "members" {
  zone_id              = var.cloudflare_zone_id
  hostnames            = [var.hostname]
  mtls_certificate_id  = cloudflare_mtls_certificate.prisma_access_ca.id
}

# Cert-only gate: decision = "non_identity" so Access doesn't try to redirect
# to an IdP login screen — it just checks for a valid client cert signed by
# the CA above. The app's own Firebase-backed login at /members/login still
# runs underneath this, unchanged.
resource "cloudflare_zero_trust_access_policy" "require_prisma_access_cert" {
  account_id = var.cloudflare_account_id
  name       = "Require Prisma Access Browser certificate"
  decision   = "non_identity"

  include = [{
    certificate = {}
  }]
}

resource "cloudflare_zero_trust_access_application" "members" {
  zone_id = var.cloudflare_zone_id
  name    = "Beyond the Firewall — Members"
  type    = "self_hosted"

  destinations = [{
    type = "public"
    uri  = "${var.hostname}${var.protected_path}"
  }]

  session_duration = "24h"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.require_prisma_access_cert.id
    precedence = 1
  }]

  depends_on = [cloudflare_certificate_authorities_hostname_associations.members]
}
