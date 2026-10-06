variable "cloudflare_api_token" {
  description = "API token with Zone:DNS/Zone Settings/WAF/Bot Management/Transform Rules:Edit on all 7 zones, and Account:Access Apps and Policies/Cloudflare Tunnel/Notifications:Edit. Enter it at the masked interactive prompt only — never in a .tfvars file or as an env var (see infra/README.md)."
  type        = string
  sensitive   = true
}
