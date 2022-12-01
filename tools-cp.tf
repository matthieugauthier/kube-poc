resource "aws_spot_instance_request" "tools-cp" {

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
  curl https://raw.githubusercontent.com/matthieugauthier/kube-poc/main/scripts/install-rancher.sh | RANCHER_INSTALL_HOSTNAME=${local.rancher_install_hostname} RANCHER_INSTALL_PASSWORD=${local.rancher_install_password} bash -

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