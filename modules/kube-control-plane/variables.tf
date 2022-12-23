variable "name" {
  type = string
}
variable "ami" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "subnet_id" {
  type = string
}
variable "private_ip" {
  type = string
}
variable "vpc_security_group_ids" {
  type = list
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
variable "rancher_install_doit" {
  type = string
}
variable "rancher_install_password" {
  type = string
}
variable "rancher_private_ip" {
  type = string
}
variable "rancher_dns" {
  type = string
}
variable "argocd_dns" {
  type = string
}
variable "vault_dns" {
  type = string
}