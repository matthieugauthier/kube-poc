resource "aws_spot_instance_request" "control-plane" {

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
		destination = "/home/ubuntu/tls_crt.pem"
	}
	# Upload Private SSH Key
	provisioner "file" {
		content     = var.tls_key
		destination = "/home/ubuntu/tls_key.pem"
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

  if [ "${var.rancher_install_doit}" == "yes" ]; then
    echo "*** Install cert-manager"
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml
    helm repo add jetstack https://charts.jetstack.io
    helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.7.1
    sleep 30

    echo "*** Prepare certs"
    kubectl create namespace cattle-system
    kubectl create secret tls wildcard-tls --cert=/home/ubuntu/tls_crt.pem --key=/home/ubuntu/tls_key.pem --namespace cattle-system
    sleep 30

    echo "*** Install rancher"
    helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
    helm install rancher rancher-latest/rancher --namespace cattle-system --set ingress.tls.source=rancher --set ingress.tls.secretName=wildcard-tls --set hostname=${var.rancher_install_hostname} --set replicas=1 --set bootstrapPassword=${var.rancher_install_password}

    echo "*** Wait Rancher"
    kubectl -n cattle-system rollout status deploy/rancher
    echo "*** Completed Installing RKE2 + Rancher"
  else
    echo "${var.rancher_private_ip} rancher.gauthier.se" >> /etc/hosts
    echo "*** Completed Installing RKE2 Without Rancher"
  fi

  EOF

  tags = {
    Name = "${var.name}"
  }

  volume_tags = {
    Name = "${var.name}"
  } 
}
resource "aws_ec2_tag" "control-plane" {
  resource_id = aws_spot_instance_request.control-plane.spot_instance_id

  key      = "Name"
  value    = "${var.name}"
}