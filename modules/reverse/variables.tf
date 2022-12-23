variable "ami" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "subnet_id" {
  type = string
}
variable "vpc_security_group_ids" {
  type = list
}
variable "eip" {
  type = string
}
variable "key_private" {
  type = string
}
variable "key_public" {
  type = string
}
variable "tls_crt" {
  type = string
}
variable "tls_key" {
  type = string
}

variable "harbor_dns" {
  type = string
}
variable "harbor_ip" {
  type = string
}
variable "vault_dns" {
  type = string
}
variable "vault_ip" {
  type = string
}
variable "conjur_dns" {
  type = string
}
variable "conjur_ip" {
  type = string
}
variable "rancher_dns" {
  type = string
}
variable "rancher_ip" {
  type = string
}
variable "argocd_dns" {
  type = string
}
variable "argocd_ip" {
  type = string
}
variable "tools_ip" {
  type = string
}
variable "production_ip" {
  type = string
}


