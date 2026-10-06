variable "cloudflare_api_token" {
  description = "API token with Account:Cloudflare Tunnel:Edit, Account:Access:Apps and Policies:Edit, Zone:DNS:Edit, and Zone:WAF:Edit (for the SSH rate-limit ruleset) permissions. Enter it at the masked interactive prompt only — never in a .tfvars file or as an env var (see infra/README.md)."
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

variable "extra_site_domains" {
  description = "Apex domains (besides .io) whose apex and www hostnames are routed to the Pi's website via tunnel ingress. Their DNS lives in separate Cloudflare zones and is dashboard-managed, not Terraform — this only controls tunnel ingress, which is account-level."
  type        = list(string)
  default     = [
    "beyondthefirewall.me",
    "beyondthefirewall.org",
    "beyondthefirewall.app",
    "beyondthefirewall.co.uk",
    "beyondthefirewall.info",
    "beyondthefirewall.uk",
  ]
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
  description = "Email addresses allowed to open a browser SSH session at console_hostname. Cloudflare requires each one's local part (before the @) to match a real Unix username on the Pi — see infra/README.md. Keep this in sync with whatever allowlist already gates members.html if they're meant to be the same people — that one is dashboard-managed and not visible to this Terraform."
  type        = list(string)
}
