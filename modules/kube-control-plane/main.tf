resource "aws_spot_instance_request" "control-plane" {

  ami             = var.ami
  instance_type   = var.instance_type
  spot_price      = "0.1"
  key_name        = "spot_key"
  subnet_id       = var.subnet_id
  private_ip      = var.private_ip
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

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for user data script to finish'",
      "cloud-init status --wait > /dev/null"
    ]
  }

  user_data = <<-EOF
  #!/bin/bash

  hostname -b "${var.name}-$(hostname)"

  echo "*** Installing RKE2 - Server Node"
  apt update -y
  curl -sfL https://get.rke2.io | sudo sh -
  systemctl enable rke2-server.service
  systemctl start rke2-server.service

  echo "*** Install HELM"
  curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg
  apt-get install apt-transport-https --yes
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
  apt-get update
  apt-get install helm

  echo "*** Install Argocd CLI"
  curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
  rm argocd-linux-amd64

  echo "*** Configure Local Kubectl"
  cp /etc/rancher/rke2/rke2.yaml /home/ubuntu/rke2.yaml
  chown ubuntu:ubuntu /home/ubuntu/rke2.yaml
  ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
  CLUSTER_NAME=${replace(var.name, "kube-cp-","")}
  sed -i "s/default/$CLUSTER_NAME/" /home/ubuntu/rke2.yaml
  CLUSTER_IP=$(hostname -I|cut -d' ' -f1)
  sed -i "s/127.0.0.1/$CLUSTER_IP/" /home/ubuntu/rke2.yaml
  echo "export KUBECONFIG=/home/ubuntu/rke2.yaml" >> /home/ubuntu/.profile
  export KUBECONFIG=/home/ubuntu/rke2.yaml

  echo "*** Wait RKE2 UP and Running"
  while [[ $(kubectl get po -A | grep -v Completed | grep -v Running | wc -l) != "1" ]]
  do
      echo "Wait RKE2";sleep 5
  done
  sleep 10

  echo "*** Prepare etc hosts"
  echo "${var.rancher_private_ip} ${var.rancher_dns} ${var.argocd_dns}" >> /etc/hosts

  if [ "${var.rancher_install_doit}" == "yes" ]; then
    echo "*** Install cert-manager"
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml
    helm repo add jetstack https://charts.jetstack.io
    helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.7.1
    while [[ $(kubectl get po --namespace cert-manager | grep -v Completed | grep -v Running | wc -l) != "1" ]]||[[ $(kubectl get po --namespace cert-manager | grep Running | wc -l) != "3" ]]
    do
        echo "Wait cert-manager";sleep 5
    done
    sleep 5

    echo "*** Prepare certs"
    kubectl create namespace cattle-system
    sed -i "s/###TLSCRT###/${base64encode(var.tls_crt)}/" /home/ubuntu/wild-tls.yml
    sed -i "s/###TLSKEY###/${base64encode(var.tls_key)}/" /home/ubuntu/wild-tls.yml
    kubectl apply -n cattle-system -f /home/ubuntu/wild-tls.yml
    sleep 30

    echo "*** Install rancher"
    helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
    helm install rancher rancher-latest/rancher --namespace cattle-system --set ingress.tls.source=rancher --set ingress.tls.secretName=wild-tls --set hostname=${var.rancher_dns} --set replicas=3 --set bootstrapPassword=${var.rancher_install_password}

    echo "*** Wait Rancher"
    kubectl -n cattle-system rollout status deploy/rancher
    sleep 5
 
    echo "*** Install argocd"
    sed -i "s/###ARGOCDDNS###/${var.argocd_dns}/" /home/ubuntu/argocd-ui.yml
    kubectl create namespace argocd
    kubectl apply -n argocd -f /home/ubuntu/wild-tls.yml
    kubectl apply -n argocd -f /home/ubuntu/argocd.yml
    kubectl apply -n argocd -f /home/ubuntu/argocd-ui.yml
    kubectl apply -n cattle-system -f /home/ubuntu/wild-tls.yml

    echo "*** Prepare argocd password"
    while [[ $(curl -s https://${var.argocd_dns}/api/version | grep 'v2' | wc -l) != "1" ]]
    do
        echo "Wait Argocd";sleep 5
    done
    sleep 5
    ARGOCD_TOKEN=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    argocd login ${var.argocd_dns} --username admin --password $ARGOCD_TOKEN --grpc-web
    argocd account update-password --account admin --new-password ${var.rancher_install_password} --current-password $ARGOCD_TOKEN
  else
    echo "*** Wait Tools CP"
    while [[ $(curl -s https://${var.argocd_dns}/api/version | grep 'v2' | wc -l) != "1" ]]
    do
        echo "Wait Argocd 1/2";sleep 5
    done
    echo "curl https://${var.argocd_dns}/api/v1/session -d '{\"username\": \"admin\", \"password\": \"${var.rancher_install_password}\"}' | grep 'token' | wc -l"
    while [[ $(curl https://${var.argocd_dns}/api/v1/session -d '{"username": "admin", "password": "${var.rancher_install_password}"}' | grep 'token' | wc -l) != "1" ]]
    do
        echo "Wait Argocd 2/2";sleep 5
    done
    sleep 5

    echo "*** Register cluster to argocd"
    argocd login ${var.argocd_dns} --username admin --password ${var.rancher_install_password} --grpc-web
    argocd cluster add $CLUSTER_NAME --grpc-web --yes

    echo "*** Prepare vault sidecar"
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm install vault hashicorp/vault --set="injector.enabled=true" --set="global.externalVaultAddr=https://${var.vault_dns}"


    echo "*** Prepare cluster rancher agent patch"
    sed -i "s/###RANCHERIP###/${var.rancher_private_ip}/" /home/ubuntu/hostalias-rancherhost-patch.yml
  fi


  echo "************************************"
  echo ""
  echo "*** Completed Cloud Init"
  echo ""
  echo ""
  echo "Cluster Name : $CLUSTER_NAME"
  echo "Cluster IP   : $CLUSTER_IP"
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