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
variable "key_private" {
  type = string
}
variable "key_public" {
  type = string
}
variable "harbor_install_hostname" {
  type = string
}
variable "harbor_install_password" {
  type = string
}