variable "cloudflare_api_token" {
  description = "API token with Zone:SSL and Certificates:Edit + Account:Access:Edit permissions. Pass via TF_VAR_cloudflare_api_token, not tfvars."
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID (dashboard URL or `Overview` sidebar)."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Zone ID for the hostname's domain."
  type        = string
}

variable "hostname" {
  description = "Hostname the client-certificate gate applies to."
  type        = string
  default     = "beyondthefirewall.me"
}

variable "protected_path" {
  description = "Path pattern gated behind the Prisma Access Browser client certificate."
  type        = string
  default     = "/members/*"
}

variable "ca_cert_path" {
  description = "Path to Prisma Access Browser's tenant root CA cert (PEM). Download from Strata Cloud Manager: Administration > Integrations > 'Prisma Access Certificate', save as Base-64 X.509 (.cer), and place it here as certs/ca.pem — the .cer is already PEM text."
  type        = string
  default     = "./certs/ca.pem"
}
