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
  access_key = local.access_key
  secret_key = local.secret_key
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
  public_key = local.keys_public
}

module "kube-control-plane-tools" {
    source                      = "./modules/kube-control-plane"

    name                        = "kube-cp-tools"
    ami                         = local.ami
    instance_type               = local.instance_type_kube
    subnet_id                   = aws_subnet.public_subnet.id
    private_ip                  = local.cp_tools_private_ip
    vpc_security_group_ids      = [aws_security_group.sg-ssh-public.id, aws_security_group.sg-http-public.id, aws_security_group.sg-internal.id]
    key_private                 = local.keys_private
    key_public                  = local.keys_public
    tls_crt                     = local.tls_crt
    tls_key                     = local.tls_key
    rancher_install_doit        = "yes"
    rancher_install_password    = local.rancher_install_password
    rancher_private_ip          = local.cp_tools_private_ip
    argocd_dns                  = local.argocd_dns
    rancher_dns                 = local.rancher_dns
    vault_dns                   = local.vault_dns
}
module "kube-nodes-tools" {
    source                      = "./modules/kube-nodes"
    depends_on                   = [module.kube-control-plane-tools]

    number                      = local.count_tools_nodes
    name                        = "kube-nodes-tools"
    ami                         = local.ami
    instance_type               = local.instance_type
    subnet_id                   = aws_subnet.public_subnet.id
    vpc_security_group_ids      = [aws_security_group.sg-ssh-public.id, aws_security_group.sg-http-public.id, aws_security_group.sg-internal.id]
    key_private                 = local.keys_private
    key_public                  = local.keys_public
    controle_plane_private_ip   = module.kube-control-plane-tools.private_ip
    controle_plane_id           = module.kube-control-plane-tools.spot_instance_id
}
module "kube-control-plane-production" {
    source                      = "./modules/kube-control-plane"

    name                        = "kube-cp-production"
    ami                         = local.ami
    instance_type               = local.instance_type_kube
    subnet_id                   = aws_subnet.public_subnet.id
    private_ip                  = local.cp_production_private_ip
    vpc_security_group_ids      = [aws_security_group.sg-ssh-public.id, aws_security_group.sg-http-public.id, aws_security_group.sg-internal.id]
    key_private                 = local.keys_private
    key_public                  = local.keys_public
    tls_crt                     = local.tls_crt
    tls_key                     = local.tls_key
    rancher_install_doit        = "no"
    rancher_install_password    = local.rancher_install_password
    rancher_private_ip          = local.cp_tools_private_ip
    argocd_dns                  = local.argocd_dns
    rancher_dns                 = local.rancher_dns
    vault_dns                   = local.vault_dns
}
module "kube-nodes-production" {
    source                      = "./modules/kube-nodes"
    depends_on                   = [module.kube-control-plane-production]

    number                      = local.count_production_nodes
    name                        = "kube-nodes-production"
    ami                         = local.ami
    instance_type               = local.instance_type
    subnet_id                   = aws_subnet.public_subnet.id
    vpc_security_group_ids      = [aws_security_group.sg-ssh-public.id, aws_security_group.sg-http-public.id, aws_security_group.sg-internal.id]
    key_private                 = local.keys_private
    key_public                  = local.keys_public
    controle_plane_private_ip   = module.kube-control-plane-production.private_ip
    controle_plane_id           = module.kube-control-plane-tools.spot_instance_id
}

module "vault" {
    source                      = "./modules/vault"

    ami                         = local.ami
    instance_type               = local.instance_type
    subnet_id                   = aws_subnet.public_subnet.id
    private_ip                  = local.vault_private_ip
    vpc_security_group_ids      = [aws_security_group.sg-ssh-public.id, aws_security_group.sg-http-public.id, aws_security_group.sg-internal.id]
    key_private                 = local.keys_private
    tls_crt                     = local.tls_crt
    tls_key                     = local.tls_key
    vault_install_hostname      = local.vault_dns
}

module "harbor" {
    source                      = "./modules/harbor"

    ami                         = local.ami
    instance_type               = local.instance_type
    subnet_id                   = aws_subnet.public_subnet.id
    private_ip                  = local.harbor_private_ip
    vpc_security_group_ids      = [aws_security_group.sg-ssh-public.id, aws_security_group.sg-http-public.id, aws_security_group.sg-internal.id]
    key_private                 = local.keys_private
    key_public                  = local.keys_public
    harbor_install_hostname     = local.harbor_install_hostname
    harbor_install_password     = local.harbor_install_password
}


module "conjur" {
  source                      = "./modules/conjur"

  ami                         = local.ami
  instance_type               = local.instance_type
  subnet_id                   = aws_subnet.public_subnet.id
  private_ip                  = local.conjur_private_ip
  vpc_security_group_ids      = [aws_security_group.sg-ssh-public.id, aws_security_group.sg-http-public.id, aws_security_group.sg-internal.id]
  key_private                 = local.keys_private
  tls_crt                     = local.tls_crt
  tls_key                     = local.tls_key
  vault_install_hostname      = local.vault_dns
}

module "reverse" {
    source                      = "./modules/reverse"

    ami                         = local.ami
    instance_type               = local.instance_type
    subnet_id                   = aws_subnet.public_subnet.id
    vpc_security_group_ids      = [aws_security_group.sg-ssh-public.id, aws_security_group.sg-http-public.id, aws_security_group.sg-internal.id]
    key_private                 = local.keys_private
    key_public                  = local.keys_public
    eip                         = local.eip
    tls_crt                     = local.tls_crt
    tls_key                     = local.tls_key

    harbor_dns                  = local.harbor_dns
    harbor_ip                   = local.harbor_private_ip
    vault_dns                   = local.vault_dns
    vault_ip                    = local.vault_private_ip
    conjur_dns                  = local.conjur_dns
    conjur_ip                   = local.conjur_private_ip
    rancher_dns                 = local.rancher_dns
    rancher_ip                  = local.cp_tools_private_ip
    argocd_dns                  = local.argocd_dns
    argocd_ip                   = local.cp_tools_private_ip

    tools_ip                    = local.cp_tools_private_ip
    production_ip               = local.cp_production_private_ip
}