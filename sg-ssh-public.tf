resource "aws_security_group" "sg-ssh-public" {
  name        = "allow_ssh_from_public"
  description = "Allow ssh inbound traffic from public"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh_from_public"
  }
}
