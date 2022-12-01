output "IP_TOOLS_CP_PUBLIC" {
  description = "Public IP of Tools Control Pane"
  value       = "${aws_spot_instance_request.tools-cp.public_ip}"
}

output "IP_TOOLS_NODES_PUBLIC" {
  description = "Private IP of Tools Control Pane"
  value       = "${aws_spot_instance_request.tools-nodes.*.public_ip}"
}