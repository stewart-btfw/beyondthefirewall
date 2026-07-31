terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

provider "google" {
  project = var.project_id
}

resource "google_project_service" "certificate_manager" {
  service            = "certificatemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "network_security" {
  service            = "networksecurity.googleapis.com"
  disable_on_destroy = false
}

# Newly-enabled APIs can 403 as SERVICE_DISABLED for a short window after the
# enable call returns success — this gives propagation time before anything
# that depends on Certificate Manager / Network Security tries to use them.
resource "time_sleep" "wait_for_apis" {
  create_duration = "60s"
  depends_on = [
    google_project_service.certificate_manager,
    google_project_service.network_security,
  ]
}

# --- TLS for the hostname itself (server-side cert, Google-managed via DNS) ---

resource "google_certificate_manager_dns_authorization" "members" {
  name   = "members-dns-auth"
  domain = var.hostname

  depends_on = [time_sleep.wait_for_apis]
}

resource "google_certificate_manager_certificate" "members" {
  name = "members-cert"
  managed {
    domains            = [var.hostname]
    dns_authorizations = [google_certificate_manager_dns_authorization.members.id]
  }

  # GCP reads this back with the project *number* even though it was written
  # with the project *ID* — same resource, cosmetic diff. Without this,
  # Terraform wants to destroy/recreate a perfectly healthy certificate.
  lifecycle {
    ignore_changes = [managed[0].dns_authorizations]
  }
}

resource "google_certificate_manager_certificate_map" "members" {
  name = "members-cert-map"

  depends_on = [time_sleep.wait_for_apis]
}

resource "google_certificate_manager_certificate_map_entry" "members" {
  name         = "members-cert-map-entry"
  map          = google_certificate_manager_certificate_map.members.name
  hostname     = var.hostname
  certificates = [google_certificate_manager_certificate.members.id]
}

# --- mTLS: validates client certs against Prisma Access Browser's tenant CA ---
# ca_cert_path is Prisma Access Browser's own tenant root CA, downloaded from
# Strata Cloud Manager (Administration > Integrations). There is no private
# key to manage here — Prisma Access holds the CA key, and each browser's
# client cert lives only in that browser's TPM/Keychain.

resource "google_certificate_manager_trust_config" "prisma_access" {
  name     = "prisma-access-browser-trust-config"
  location = "global"

  trust_stores {
    trust_anchors {
      pem_certificate = file(var.ca_cert_path)
    }
  }

  depends_on = [time_sleep.wait_for_apis]
}

resource "google_network_security_server_tls_policy" "require_prisma_access_cert" {
  name     = "require-prisma-access-browser-cert"
  location = "global"

  mtls_policy {
    client_validation_mode         = "REJECT_INVALID"
    client_validation_trust_config = google_certificate_manager_trust_config.prisma_access.id
  }

  # Same project-number-vs-project-ID cosmetic diff as the certificate above.
  lifecycle {
    ignore_changes = [mtls_policy[0].client_validation_trust_config]
  }

  depends_on = [time_sleep.wait_for_apis]
}

# --- Backend: dedicated demo Cloud Run service, fully isolated from the
# production members-backend service and its traffic ---

resource "google_compute_region_network_endpoint_group" "members" {
  name                  = "members-backend-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name
  }
}

resource "google_compute_backend_service" "members" {
  name                  = "members-backend-svc"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"

  # Requests that make it past the mTLS gate to the backend get logged here.
  # Note: connections rejected by the server_tls_policy (REJECT_INVALID)
  # happen before traffic reaches the backend, so they won't appear in these
  # logs — this only helps diagnose what happens to requests that pass mTLS.
  log_config {
    enable      = true
    sample_rate = 1.0
  }

  backend {
    group = google_compute_region_network_endpoint_group.members.id
  }
}

resource "google_compute_url_map" "members" {
  name            = "members-url-map"
  default_service = google_compute_backend_service.members.id
}

resource "google_compute_target_https_proxy" "members" {
  name              = "members-https-proxy"
  url_map           = google_compute_url_map.members.id
  certificate_map   = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.members.id}"
  server_tls_policy = google_network_security_server_tls_policy.require_prisma_access_cert.id
}

resource "google_compute_global_address" "members" {
  name = "members-lb-ip"
}

resource "google_compute_global_forwarding_rule" "members" {
  name                  = "members-lb-forwarding-rule"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.members.id
  port_range            = "443"
  target                = google_compute_target_https_proxy.members.id
}
