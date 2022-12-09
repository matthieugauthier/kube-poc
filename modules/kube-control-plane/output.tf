output "spot_instance_id" {
  description = "spot_instance_id"
  value       = "${aws_spot_instance_request.control-plane.spot_instance_id}"
}
output "public_ip" {
  description = "Public IP"
  value       = "${aws_spot_instance_request.control-plane.public_ip}"
}
output "private_ip" {
  description = "Private IP"
  value       = "${aws_spot_instance_request.control-plane.private_ip}"
}