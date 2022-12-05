output "public_ip" {
  description = "Public IP"
  value       = "${aws_spot_instance_request.vault.public_ip}"
}
output "private_ip" {
  description = "Public IP"
  value       = "${aws_spot_instance_request.vault.private_ip}"
}