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
		destination = "/home/ubuntu/tls_crt.pem"
	}
	# Upload Private SSH Key
	provisioner "file" {
		content     = var.tls_key
		destination = "/home/ubuntu/tls_key.pem"
	}

	provisioner "file" {
		source      = "modules/kube-control-plane/confs/argocd.yml"
		destination = "/home/ubuntu/argocd.yml"
	}

	provisioner "file" {
		source      = "modules/kube-control-plane/confs/argocd-ui.yml"
		destination = "/home/ubuntu/argocd-ui.yml"
	}

	provisioner "file" {
		source      = "modules/kube-control-plane/confs/wild-tls.yml"
		destination = "/home/ubuntu/wild-tls.yml"
	}

	provisioner "file" {
		source      = "modules/kube-control-plane/confs/hostalias-rancherhost-patch.yml"
		destination = "/home/ubuntu/hostalias-rancherhost-patch.yml"
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
  echo "Configure Cluster Name"
  CLUSTER_NAME=${replace(var.name, "kube-cp-","")}
  echo $CLUSTER_NAME
  sed -i "s/default/$CLUSTER_NAME/" /home/ubuntu/rke2.yaml
  CLUSTER_IP=$(hostname -I|cut -d' ' -f1)
  echo $CLUSTER_IP
  sed -i "s/127.0.0.1/$CLUSTER_IP/" /home/ubuntu/rke2.yaml

  echo "*** Wait RKE2 OK"
  while [[ $(kubectl get po -A | grep -v Completed | grep -v Running | wc -l) != "1" ]]
  do
      sleep 5
  done
  sleep 20

  sed -i "s/###RANCHERIP###/${var.rancher_private_ip}/" /home/ubuntu/hostalias-rancherhost-patch.yml

  curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64


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
    helm install rancher rancher-latest/rancher --namespace cattle-system --set ingress.tls.source=rancher --set ingress.tls.secretName=wildcard-tls --set hostname=${var.rancher_dns} --set replicas=3 --set bootstrapPassword=${var.rancher_install_password}

    echo "*** Wait Rancher"
    kubectl -n cattle-system rollout status deploy/rancher
    echo "*** Completed Installing RKE2 + Rancher"
 
    echo "*** Install argocd"
    sleep 60
    sed -i "s/###TLSCRT###/${base64encode(var.tls_crt)}/" /home/ubuntu/wild-tls.yml
    sed -i "s/###TLSKEY###/${base64encode(var.tls_key)}/" /home/ubuntu/wild-tls.yml
    sed -i "s/###ARGOCDDNS###/${var.argocd_dns}/" /home/ubuntu/argocd-ui.yml
    kubectl create namespace argocd
    kubectl apply -n argocd -f /home/ubuntu/wild-tls.yml
    kubectl apply -n argocd -f /home/ubuntu/argocd.yml
    kubectl apply -n argocd -f /home/ubuntu/argocd-ui.yml
    echo "*** Completed Installing argocd"

    echo "Argocd Password:"
    sleep 30
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > /home/ubuntu/token_argocd

  else
    echo "${var.rancher_private_ip} ${var.rancher_dns} ${var.argocd_dns}" >> /etc/hosts
    echo "*** Completed Installing RKE2 Without Rancher"

    sleep 230

    echo "Get Remote Token Argo"
    TOKEN=$(ssh -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa ubuntu@${var.rancher_dns} cat /home/ubuntu/token_argocd)
    echo $TOKEN
    echo "Login Argo"
    echo "argocd login ${var.argocd_dns} --username admin --password $TOKEN --grpc-web"
    argocd login ${var.argocd_dns} --username admin --password $TOKEN --grpc-web
    echo "Add current cluster to Argo"
    argocd cluster add $CLUSTER_NAME --grpc-web --yes


    echo "Run \"kubectl patch -n cattle-system deployment cattle-cluster-agent --patch-file /home/ubuntu/hostalias-rancherhost-patch.yml\" to patch after apply rancher conf"
  fi

  echo "************************************"
  echo ""
  echo "*** Completed Cloud Init"
  echo ""
  echo ""
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