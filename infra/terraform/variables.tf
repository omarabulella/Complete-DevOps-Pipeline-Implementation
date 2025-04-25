variable "region" {
    description = "aws region to deploy resources"
    type = string
}
variable "ec2_instance_type" {
  description = "ec2 instance type for vm"
  type = string
}
variable "ami_id" {
  description = "AMI ID to use for EC2 instance"
  type        = string
}
variable "Eks_cluster_name" {
    description = "Eks cluster name"
    type = string
}
variable "vpc_cidr" {
  description = "CIDR block for vpc"
  type = string
}
variable "ssh_key_name" {
    description = "name of SSh key pair for access the ec2 "
    type = string
}
variable "ssh_key_path" {
  description = "Path to the SSH private key used to access EC2 instances"
  type        = string
}
variable "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state storage"
  type        = string
}
