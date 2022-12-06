output "public_ip" {
  description = "Public IP"
  value       = "${aws_spot_instance_request.reverse.public_ip}"
}
output "private_ip" {
  description = "Private IP"
  value       = "${aws_spot_instance_request.reverse.private_ip}"
}