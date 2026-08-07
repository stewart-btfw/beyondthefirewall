variable "cloudflare_api_token" {
  description = "API token with Account:Cloudflare Tunnel:Edit, Account:Access:Apps and Policies:Edit, Account:Device Posture:Edit, Zone:DNS:Edit permissions. Pass via TF_VAR_cloudflare_api_token, not tfvars."
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Zone ID for the domain hosting the Pi's public hostnames."
  type        = string
}

variable "tunnel_id" {
  description = "ID of the existing 'BTFW' Cloudflare Tunnel already running on the Pi."
  type        = string
  default     = "4f0e31e4-3ada-4182-b057-48153417d481"
}

variable "web_hostname" {
  description = "Public hostname for the Pi's website."
  type        = string
  default     = "web.beyondthefirewall.io"
}

variable "apex_hostname" {
  description = "Zone apex hostname, also routed to the Pi's website."
  type        = string
  default     = "beyondthefirewall.io"
}

variable "www_hostname" {
  description = "www hostname, routed to the Pi and redirected to the apex."
  type        = string
  default     = "www.beyondthefirewall.io"
}

variable "ssh_hostname" {
  description = "Public hostname for SSH access to the Pi."
  type        = string
  default     = "ssh.beyondthefirewall.io"
}

variable "metrics_hostname" {
  description = "Public hostname for the Pi's node_exporter metrics (basic-auth protected by nginx)."
  type        = string
  default     = "metrics.beyondthefirewall.io"
}

variable "web_port" {
  description = "Local port the Pi's web server listens on."
  type        = number
  default     = 80
}
