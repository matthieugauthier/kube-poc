resource "aws_spot_instance_request" "harbor" {
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

  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing Harbor"

  echo "$(hostname -i | cut -d' ' -f1) ${var.harbor_install_hostname}" >> /etc/hosts

  curl https://raw.githubusercontent.com/matthieugauthier/kube-poc/main/scripts/install-harbor.sh | IPorFQDN=${var.harbor_install_hostname} bash -

  echo "*** Completed Installing Harbor"
  EOF

  tags = {
    Name = "harbor"
  }

  volume_tags = {
    Name = "harbor"
  } 
}
resource "aws_ec2_tag" "harbor" {
  resource_id = aws_spot_instance_request.harbor.spot_instance_id

  key      = "Name"
  value    = "harbor"
}