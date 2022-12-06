resource "aws_security_group" "sg-internal" {
  name        = "allow_all_internal"
  description = "Allow RKE2 http inbound traffic"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description      = "Allow all in internal"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["10.0.0.0/16"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  tags = {
    Name = "allow_all_internal"
  }
}
