output "load_balancer_ip_address" {
  description = "Internal IP address of the load balancer"
  value       = module.ilb.ip_address
}


