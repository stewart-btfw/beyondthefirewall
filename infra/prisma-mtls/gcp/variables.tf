variable "project_id" {
  description = "GCP project hosting the Cloud Run service."
  type        = string
  default     = "beyondthefirewall"
}

variable "region" {
  description = "Region of the existing members-backend Cloud Run service."
  type        = string
  default     = "australia-southeast1"
}

variable "cloud_run_service_name" {
  description = "Name of the dedicated demo Cloud Run service (isolated from the production members-backend service — see .github/workflows/deploy-members-backend-demo.yml)."
  type        = string
  default     = "members-backend-demo"
}

variable "hostname" {
  description = "Dedicated hostname for the demo, pointed DNS-only (no Cloudflare proxy) at this load balancer's IP."
  type        = string
  default     = "members.beyondthefirewall.me"
}

variable "ca_cert_path" {
  description = "Path to Prisma Access Browser's tenant root CA cert (PEM). Download from Strata Cloud Manager: Administration > Integrations > 'Prisma Access Certificate', save as Base-64 X.509 (.cer), and place it here as certs/ca.pem — the .cer is already PEM text."
  type        = string
  default     = "./certs/ca.pem"
}
