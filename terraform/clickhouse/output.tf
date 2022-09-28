output "service_account_email" {
  description = "the email of serviceAccount used to run the VMs"
  value       = google_service_account.default.email
}

output "load_balancer_ip_address" {
  description = "Internal IP address of the load balancer"
  value       = module.ilb.ip_address
}



