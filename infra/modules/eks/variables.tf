variable "project" {
  description = "Project name for EKS resources"
  type        = string
}

variable "desired_nodes" {
  description = "Desired number of EKS nodes"
  type        = number
}

variable "max_nodes" {
  description = "Maximum number of EKS nodes"
  type        = number
}

variable "min_nodes" {
  description = "Minimum number of EKS nodes"
  type        = number
}

variable "node_instance_type" {
  description = "EKS node instance type"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
} 