variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "allowed_ssh_ip" {
  type = string
}

variable "root_volume_size" {
  type = number
}

variable "enable_termination_protection" {
  type = bool
}