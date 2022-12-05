output "public_ip" {
  description = "Public IP"
  value       = "${aws_spot_instance_request.harbor.public_ip}"
}
output "private_ip" {
  description = "Private IP"
  value       = "${aws_spot_instance_request.harbor.private_ip}"
}