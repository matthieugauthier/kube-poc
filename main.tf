terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region     = "eu-west-1"
  access_key = ""
  secret_key = ""
}


resource "aws_vpc" "app_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "app-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "vpc_igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-1a"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rt"
  }
}


resource "aws_route_table_association" "public_rt_asso" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_key_pair" "spot_key" {
  key_name   = "spot_key"
  public_key = "${file("/Users//.ssh/id_rsa.pub")}"
}

resource "aws_spot_instance_request" "tools-cp" {
  ami             = "ami-001c2751d5252c623" 
  instance_type   = "t3.medium"  
  spot_price      = "0.1"
  key_name        = "spot_key"
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.sg.id, aws_security_group.sg-kube.id]
  wait_for_fulfillment = true


  root_block_device {
    volume_size           = "40"
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing RKE2"
  sudo apt update -y
  curl -sfL https://get.rke2.io | sudo sh -
  sudo systemctl enable rke2-server.service
  sudo systemctl start rke2-server.service

  echo "*** Install HELM"
  curl https://raw.githubusercontent.com/matthieugauthier/kube-poc/main/scripts/install-helm.sh | bash -
  
  echo "*** Make Local Kubectl Working"
  sudo cp /etc/rancher/rke2/rke2.yaml /home/ubuntu/rke2.yaml
  sudo chown ubuntu:ubuntu /home/ubuntu/rke2.yaml
  ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
  echo "export KUBECONFIG=/home/ubuntu/rke2.yaml" >> /home/ubuntu/.profile
  export KUBECONFIG=/home/ubuntu/rke2.yaml

  echo "*** Wait RKE2 OK"
  while [[ $(kubectl get po -A | grep -v Completed | grep -v Running | wc -l) != "1" ]]
  do
      sleep 5
  done
  sleep 20

  echo "*** Install Rancher"
  curl https://raw.githubusercontent.com/matthieugauthier/kube-poc/main/scripts/install-rancher.sh | RANCHER_INSTALL_HOSTNAME="" RANCHER_INSTALL_PASSWORD="" bash -

  echo "*** Wait Rancher"
  kubectl -n cattle-system rollout status deploy/rancher

  echo "*** Completed Installing RKE2 + Rancher"
  EOF

  tags = {
    Name = "tools-cp"
  }

  volume_tags = {
    Name = "tools-cp"
  } 
}

resource "aws_spot_instance_request" "tools-n1" {
  ami             = "ami-001c2751d5252c623" 
  instance_type   = "t3.medium"  
  spot_price      = "0.1"
  key_name        = "spot_key"
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.sg.id, aws_security_group.sg-kube.id]
  wait_for_fulfillment = true


  root_block_device {
    volume_size           = "40"
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing RKE2"
  sudo apt update -y
  curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_TYPE="agent" sh -
  sudo systemctl enable rke2-server.service
  mkdir -p /etc/rancher/rke2/

  echo "*** Completed Installing RKE2"
  EOF

  tags = {
    Name = "tools-n1"
  }

  volume_tags = {
    Name = "tools-n1"
  } 
}
