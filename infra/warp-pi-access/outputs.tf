output "web_url" {
  value = "https://${var.web_hostname}"
}

output "apex_url" {
  value = "https://${var.apex_hostname}"
}

output "ssh_hostname" {
  value = var.ssh_hostname
}

output "canonical_url" {
  value = "https://${var.canonical_domain}"
}

# Paste into the CF_ACCESS_CLIENT_ID GitHub Actions secret.
output "deploy_service_token_client_id" {
  value = cloudflare_zero_trust_access_service_token.deploy.client_id
}

# Paste into the CF_ACCESS_CLIENT_SECRET GitHub Actions secret. Only
# retrievable via `terraform output -raw deploy_service_token_client_secret`.
output "deploy_service_token_client_secret" {
  value     = cloudflare_zero_trust_access_service_token.deploy.client_secret
  sensitive = true
}

output "deploy_service_token_expires_at" {
  value = cloudflare_zero_trust_access_service_token.deploy.expires_at
}
