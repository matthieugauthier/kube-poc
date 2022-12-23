output "public_ip" {
  description = "Public IP"
  value       = "${aws_spot_instance_request.conjur.public_ip}"
}
output "private_ip" {
  description = "Public IP"
  value       = "${aws_spot_instance_request.conjur.private_ip}"
}