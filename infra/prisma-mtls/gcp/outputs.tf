output "load_balancer_ip" {
  description = "Point members.beyondthefirewall.me's A record (DNS-only, not proxied) at this IP."
  value       = google_compute_global_address.members.address
}

output "dns_authorization_record" {
  description = "CNAME record required before the Google-managed certificate can be issued. Add this alongside the A record above."
  value = {
    name = google_certificate_manager_dns_authorization.members.dns_resource_record[0].name
    type = google_certificate_manager_dns_authorization.members.dns_resource_record[0].type
    data = google_certificate_manager_dns_authorization.members.dns_resource_record[0].data
  }
}
