variable "name" {
  type = string
}
variable "number" {
  type = number
  description = "The number of nodes wanted."
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
variable "vpc_security_group_ids" {
  type = list
}
variable "key_private" {
  type = string
}
variable "key_public" {
  type = string
}
variable "controle_plane_private_ip" {
  type = string
}
variable "controle_plane_id" {
  type = string
}