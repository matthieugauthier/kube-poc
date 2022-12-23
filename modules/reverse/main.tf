resource "aws_eip_association" "eip_assoc" {
  instance_id   = "${aws_spot_instance_request.reverse.spot_instance_id}"
  allocation_id = var.eip
}

resource "aws_spot_instance_request" "reverse" {
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

	
	provisioner "file" {
		source      = "modules/reverse/confs/harbor.conf"
		destination = "/home/ubuntu/harbor.conf"
	}
	provisioner "file" {
		source      = "modules/reverse/confs/vault.conf"
		destination = "/home/ubuntu/vault.conf"
	}
	provisioner "file" {
		source      = "modules/reverse/confs/conjur.conf"
		destination = "/home/ubuntu/conjur.conf"
	}
	provisioner "file" {
		source      = "modules/reverse/confs/rancher.conf"
		destination = "/home/ubuntu/rancher.conf"
	}
	provisioner "file" {
		source      = "modules/reverse/confs/argocd.conf"
		destination = "/home/ubuntu/argocd.conf"
	}

  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing Reverse Proxy"

  hostname -b "reverse-$(hostname)"
  while [ ! -f /home/ubuntu/.ssh/id_rsa ]; do sleep 2; done;
  chmod 400 /home/ubuntu/.ssh/id_rsa
  while [ ! -f /home/ubuntu/.ssh/id_rsa.pub ]; do sleep 2; done;
  chmod 400 /home/ubuntu/.ssh/id_rsa.pub

  apt install -y apache2
  a2enmod ssl proxy proxy_http proxy_wstunnel rewrite

  sleep 30 
  
  cp /home/ubuntu/harbor.conf /etc/apache2/sites-available/harbor.conf
  sed -i "s/###HARBORDNS###/${var.harbor_dns}/" /etc/apache2/sites-available/harbor.conf
  echo "${var.harbor_ip} ${var.harbor_dns} harbor" >> /etc/hosts
  a2ensite harbor

  cp /home/ubuntu/vault.conf /etc/apache2/sites-available/vault.conf
  sed -i "s/###VAULTDNS###/${var.vault_dns}/" /etc/apache2/sites-available/vault.conf
  echo "${var.vault_ip} ${var.vault_dns} vault" >> /etc/hosts
  a2ensite vault

  cp /home/ubuntu/conjur.conf /etc/apache2/sites-available/conjur.conf
  sed -i "s/###CONJURDNS###/${var.conjur_dns}/" /etc/apache2/sites-available/conjur.conf
  echo "${var.conjur_ip} ${var.conjur_dns} conjur" >> /etc/hosts
  a2ensite conjur

  cp /home/ubuntu/rancher.conf /etc/apache2/sites-available/rancher.conf
  sed -i "s/###RANCHERDNS###/${var.rancher_dns}/" /etc/apache2/sites-available/rancher.conf
  echo "${var.rancher_ip} ${var.rancher_dns} rancher" >> /etc/hosts
  a2ensite rancher

  cp /home/ubuntu/argocd.conf /etc/apache2/sites-available/argocd.conf
  sed -i "s/###ARGOCDDNS###/${var.argocd_dns}/" /etc/apache2/sites-available/argocd.conf
  echo "${var.argocd_ip} ${var.argocd_dns}" >> /etc/hosts
  a2ensite argocd
  
  systemctl restart apache2

  echo "${var.tools_ip} tools" >> /etc/hosts
  echo "${var.production_ip} production" >> /etc/hosts

  echo "*** Completed Reverse Proxy"
  EOF

  tags = {
    Name = "reverse"
  }

  volume_tags = {
    Name = "reverse"
  } 
}
resource "aws_ec2_tag" "node" {
  resource_id = aws_spot_instance_request.reverse.spot_instance_id
  
  key      = "Name"
  value    = "reverse"
}