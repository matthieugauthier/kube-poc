resource "aws_spot_instance_request" "vault" {
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
		content     = var.tls_crt
		destination = "/home/ubuntu/tls.crt"
	}

	# Upload Public SSH Key
	provisioner "file" {
		content     = var.tls_key
		destination = "/home/ubuntu/tls.key"
	}

  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing Vault"

  hostname -b "vault-$(hostname)"
  echo "$(hostname -i | cut -d' ' -f1) ${var.vault_install_hostname}" >> /etc/hosts

  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt update && sudo apt install vault

  mv /home/ubuntu/tls.crt /opt/vault/tls/tls.crt
  mv /home/ubuntu/tls.key /opt/vault/tls/tls.key

  systemctl start vault

  vault  operator init -key-shares=1 -key-threshold=1 -address=https://vault.gauthier.se:8200

  echo "*** Completed Vault"
  EOF

  tags = {
    Name = "vault"
  }

  volume_tags = {
    Name = "vault"
  } 
}
resource "aws_ec2_tag" "vault" {
  resource_id = aws_spot_instance_request.vault.spot_instance_id

  key      = "Name"
  value    = "vault"
}