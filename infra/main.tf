terraform {
    backend "s3" {
        bucket = "my-terraform-state-bucket-jk-tf-user-vicky"
        region = "ca-central-1"
        key = "terraform.tfstate"
    }
}

provider "aws" {
    region = var.aws_region
}

module "rds" {
    source = "./modules/rds"
    project            = var.eks_project
    instance_class        = var.rds_instance_class
    allocated_storage     = var.rds_allocated_storage
    max_allocated_storage = var.rds_max_allocated_storage
    username             = var.rds_username
    password             = var.rds_password
    environment          = var.environment
}

module "eks" {
    source = "./modules/eks"
    
    project            = var.eks_project
    desired_nodes      = var.eks_desired_nodes
    max_nodes          = var.eks_max_nodes
    min_nodes          = var.eks_min_nodes
    node_instance_type = var.eks_node_instance_type
    environment        = var.environment
}

module "s3" {
    source = "./modules/s3"
    
    bucket_name  = var.s3_bucket_name
    environment  = var.s3_environment
}