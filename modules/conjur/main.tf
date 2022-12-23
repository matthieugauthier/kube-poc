resource "aws_spot_instance_request" "conjur" {
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

  hostname -b "conjur-$(hostname)"

  while [ ! -f /home/ubuntu/tls.crt ]; do sleep 2; done;
  while [ ! -f /home/ubuntu/tls.key ]; do sleep 2; done;

  apt-get install -y ca-certificates curl gnupg lsb-release
  mkdir -p /etc/apt/keyring
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  apt-get install -y docker-compose-plugin
  apt install -y git

  git clone https://github.com/cyberark/conjur-quickstart.git
  cd conjur-quickstart/

  cp /home/ubuntu/tls.crt /conjur-quickstart/conf/tls/nginx.crt
  cp /home/ubuntu/tls.key /conjur-quickstart/conf/tls/nginx.key
  sed -i '3,24d' docker-compose.yml
  sed -i 's/   - openssl//' docker-compose.yml

  docker compose pull
  docker compose run --no-deps --rm conjur data-key generate > data_key
  export CONJUR_DATA_KEY="$(< data_key)"
  echo $CONJUR_DATA_KEY
  docker compose up -d
  docker compose exec conjur conjurctl account create myConjurAccount > admin_data
  cat admin_data
  docker compose exec client conjur init -u conjur -a myConjurAccount

  echo "*** Completed conjur"
  EOF

  tags = {
    Name = "conjur"
  }

  volume_tags = {
    Name = "conjur"
  } 
}
resource "aws_ec2_tag" "vault" {
  resource_id = aws_spot_instance_request.conjur.spot_instance_id

  key      = "Name"
  value    = "conjur"
}