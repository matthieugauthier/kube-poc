resource "aws_spot_instance_request" "tools-nodes" {
  count           = local.count_tools_nodes

  ami             = local.ami
  instance_type   = local.instance_type
  spot_price      = "0.1"
  key_name        = "spot_key"
  subnet_id       = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.sg.id, aws_security_group.sg-kube.id]
  wait_for_fulfillment = true


  root_block_device {
    volume_size           = "40"
    volume_type           = "gp2"
    delete_on_termination = true
  }

	connection {
		type         = "ssh"
		host         = self.public_ip
		user         = "ubuntu"
		private_key  = local.keys_private
	}

	# Upload Private SSH Key
	provisioner "file" {
		content     = local.keys_private
		destination = "/home/ubuntu/.ssh/id_rsa"
	}

	# Upload Public SSH Key
	provisioner "file" {
		content     = local.keys_public
		destination = "/home/ubuntu/.ssh/id_rsa.pub"
	}

  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing RKE2"
  apt update -y

  curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
  systemctl enable rke2-agent.service
  mkdir -p /etc/rancher/rke2/

  chmod 600 /home/ubuntu/.ssh/id_rsa*
  
  CP_IP=${aws_spot_instance_request.tools-cp.private_ip}
  TOKEN=$(ssh -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP_IP sudo cat /var/lib/rancher/rke2/server/node-token)
  echo "server: https://$CP_IP:9345" > /etc/rancher/rke2/config.yaml
  echo "token: $TOKEN" >> /etc/rancher/rke2/config.yaml

  systemctl start rke2-agent.service

  echo "*** Completed Installing RKE2"
  EOF

  tags = {
    Name = "tools-n1"
  }

  volume_tags = {
    Name = "tools-n1"
  } 

  depends_on = [
    aws_spot_instance_request.tools-cp
  ]
}
