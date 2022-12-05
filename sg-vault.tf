resource "aws_security_group" "sg-vault" {
  name        = "allow_vault"
  description = "Allow ssh http inbound traffic"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 8200
    to_port          = 8200
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}
