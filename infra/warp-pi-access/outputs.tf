output "web_url" {
  value = "https://${var.web_hostname}"
}

output "apex_url" {
  value = "https://${var.apex_hostname}"
}

output "ssh_hostname" {
  value = var.ssh_hostname
}
