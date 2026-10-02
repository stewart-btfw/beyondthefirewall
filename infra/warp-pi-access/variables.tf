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

variable "web_port" {
  description = "Local port the Pi's web server listens on."
  type        = number
  default     = 80
}

variable "me_apex_hostname" {
  description = "beyondthefirewall.me apex, also routed to the Pi (separate zone from .io — DNS for this one is dashboard-managed, not Terraform, since this project only holds the .io zone_id)."
  type        = string
  default     = "beyondthefirewall.me"
}

variable "me_www_hostname" {
  description = "www.beyondthefirewall.me, routed to the Pi and redirected to the apex."
  type        = string
  default     = "www.beyondthefirewall.me"
}

variable "org_apex_hostname" {
  description = "beyondthefirewall.org apex, also routed to the Pi (separate zone from .io — DNS for this one is dashboard-managed, not Terraform)."
  type        = string
  default     = "beyondthefirewall.org"
}

variable "org_www_hostname" {
  description = "www.beyondthefirewall.org, routed to the Pi and redirected to the apex."
  type        = string
  default     = "www.beyondthefirewall.org"
}

variable "app_apex_hostname" {
  description = "beyondthefirewall.app apex, also routed to the Pi (separate zone from .io — DNS for this one is dashboard-managed, not Terraform)."
  type        = string
  default     = "beyondthefirewall.app"
}

variable "app_www_hostname" {
  description = "www.beyondthefirewall.app, routed to the Pi and redirected to the apex."
  type        = string
  default     = "www.beyondthefirewall.app"
}

variable "co_uk_apex_hostname" {
  description = "beyondthefirewall.co.uk apex, also routed to the Pi (separate zone from .io — DNS for this one is dashboard-managed, not Terraform)."
  type        = string
  default     = "beyondthefirewall.co.uk"
}

variable "co_uk_www_hostname" {
  description = "www.beyondthefirewall.co.uk, routed to the Pi and redirected to the apex."
  type        = string
  default     = "www.beyondthefirewall.co.uk"
}

variable "info_apex_hostname" {
  description = "beyondthefirewall.info apex, also routed to the Pi (separate zone from .io — DNS for this one is dashboard-managed, not Terraform)."
  type        = string
  default     = "beyondthefirewall.info"
}

variable "info_www_hostname" {
  description = "www.beyondthefirewall.info, routed to the Pi and redirected to the apex."
  type        = string
  default     = "www.beyondthefirewall.info"
}

variable "uk_apex_hostname" {
  description = "beyondthefirewall.uk apex, also routed to the Pi (separate zone from .io — DNS for this one is dashboard-managed, not Terraform)."
  type        = string
  default     = "beyondthefirewall.uk"
}

variable "uk_www_hostname" {
  description = "www.beyondthefirewall.uk, routed to the Pi and redirected to the apex."
  type        = string
  default     = "www.beyondthefirewall.uk"
}

variable "console_hostname" {
  description = "Dedicated hostname for browser-rendered SSH (Cloudflare Access renders an in-browser terminal here — it can't be a path on members.html, only a whole domain/subdomain). Separate from ssh_hostname, which stays key-only and ungated by Access. DNS for this one is dashboard-managed, not Terraform (same as the rest of the .me zone)."
  type        = string
  default     = "console.beyondthefirewall.me"
}

variable "cloudflare_team_name" {
  description = "Zero Trust team name (the <team> in <team>.cloudflareaccess.com), found in Zero Trust > Settings > Custom Pages, or the URL when logged into the dashboard. Required to gate the tunnel ingress rule for console_hostname behind the console_ssh Access application."
  type        = string
}

variable "console_allowed_emails" {
  description = "Email addresses allowed to open a browser SSH session at console_hostname. Keep this in sync with whatever allowlist already gates members.html if they're meant to be the same people — that one is dashboard-managed and not visible to this Terraform."
  type        = list(string)
}

variable "console_ssh_username" {
  description = "Unix username on the Pi that browser SSH sessions log in as. The Pi has one real user (liversalts); anyone who passes the console_allowed_emails policy gets a shell as this user — access control happens entirely at the Access policy layer, not via per-person Unix accounts."
  type        = string
  default     = "liversalts"
}
