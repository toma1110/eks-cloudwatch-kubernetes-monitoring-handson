variable "aws_region" {
  description = "AWS region for the hands-on environment."
  type        = string
  default     = "ap-northeast-1"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "eks-cw-handson"
}

variable "node_instance_type" {
  description = "EC2 instance type for the learning node group."
  type        = string
  default     = "t3.small"
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default = {
    Course  = "eks-cloudwatch-kubernetes-monitoring"
    Purpose = "udemy-handson"
  }
}
