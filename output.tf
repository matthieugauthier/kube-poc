output "public_ip" {
  description = "List of public IP addresses assigned to the instances, if applicable"
  value       = "IP_TOOLS_CP=${aws_spot_instance_request.tools-cp.public_ip}"
}
output "public_ipn1" {
  description = "List of public IP addresses assigned to the instances, if applicable"
  value       = "IP_TOOLS_N1=${aws_spot_instance_request.tools-n1.public_ip}"
}