resource "aws_security_group" "sg-kube" {
  name        = "allow_rke2"
  description = "Allow RKE2 http inbound traffic"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description      = "The RKE2 server needs port 6443 and 9345 to be accessible by other nodes in the cluster."
    from_port        = 6443
    to_port          = 6443
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "The RKE2 server needs port 6443 and 9345 to be accessible by other nodes in the cluster."
    from_port        = 9345
    to_port          = 9345
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "If you wish to utilize the metrics server, you will need to open port 10250 on each node."
    from_port        = 10250
    to_port          = 10250
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  tags = {
    Name = "allow_ssh_http"
  }
}
