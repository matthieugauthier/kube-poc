resource "aws_spot_instance_request" "node" {
  count           = var.number
  ami             = var.ami
  instance_type   = var.instance_type
  spot_price      = "0.1"
  key_name        = "spot_key"
  subnet_id       = var.subnet_id
  vpc_security_group_ids = var.vpc_security_group_ids
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
        private_key  = var.key_private
    }

    # Upload Private SSH Key
    provisioner "file" {
        content     = var.key_private
        destination = "/home/ubuntu/.ssh/id_rsa"
    }

    # Upload Public SSH Key
    provisioner "file" {
        content     = var.key_public
        destination = "/home/ubuntu/.ssh/id_rsa.pub"
    }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for user data script to finish'",
      "cloud-init status --wait > /dev/null"
    ]
  }

  user_data = <<-EOF
  #!/bin/bash
  echo "${var.controle_plane_id}"

  hostname -b "${var.name}-node-${count.index+1}-$(hostname)"

  echo "*** Installing RKE2 Node"
  apt update -y

  curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
  systemctl enable rke2-agent.service
  mkdir -p /etc/rancher/rke2/

  while [ ! -f /home/ubuntu/.ssh/id_rsa ]; do sleep 2; done;
  while [ ! -f /home/ubuntu/.ssh/id_rsa.pub ]; do sleep 2; done;

  chmod 600 /home/ubuntu/.ssh/id_rsa*
  
  CP_IP=${var.controle_plane_private_ip}
  TOKEN=$(ssh -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa ubuntu@$CP_IP sudo cat /var/lib/rancher/rke2/server/node-token)
  echo "server: https://$CP_IP:9345" > /etc/rancher/rke2/config.yaml
  echo "token: $TOKEN" >> /etc/rancher/rke2/config.yaml

  systemctl start rke2-agent.service

  echo "*** Completed Installing RKE2 Node"
  EOF

  tags = {
    Name = "${var.name}-node-${count.index+1}"
  }

  volume_tags = {
    Name = "${var.name}-node-${count.index+1}"
  }
}
resource "aws_ec2_tag" "node" {
  count           = var.number

  resource_id = aws_spot_instance_request.node[count.index].spot_instance_id
  
  key      = "Name"
  value    = "${var.name}-node-${count.index+1}"
}