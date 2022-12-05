output "tools_cp_public_ip" {
  value       = "${module.kube-control-plane-tools.public_ip}"
}
output "tools_cp_private_ip" {
  value       = "${module.kube-control-plane-tools.private_ip}"
}
output "tools_no_public_ip" {
  value       = "${module.kube-nodes-tools.public_ips}"
}

output "production_cp_public_ip" {
  value       = "${module.kube-control-plane-production.public_ip}"
}
output "production_cp_private_ip" {
  value       = "${module.kube-control-plane-production.public_ip}"
}
output "production_no_public_ip" {
  value       = "${module.kube-nodes-production.public_ips}"
}

output "harbor_public_ip" {
  value       = "${module.harbor.public_ip}"
}
output "harbor_private_ip" {
  value       = "${module.harbor.private_ip}"
}

output "vault_public_ip" {
  value       = "${module.vault.public_ip}"
}
output "vault_private_ip" {
  value       = "${module.vault.private_ip}"
}

output "IP_REVERSE_PROXY_PUBLIC" {
  description = "Public IP of Tools Control Pane"
  value       = "${aws_spot_instance_request.reverse-proxy.public_ip}"
}

