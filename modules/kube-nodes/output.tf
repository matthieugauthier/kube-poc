output "public_ips" {
  description = "Publics IP"
  value       = "${aws_spot_instance_request.node.*.public_ip}"
}