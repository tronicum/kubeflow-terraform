terraform {
  required_version = ">= 0.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    mysql = {
      source  = "terraform-providers/mysql"
      version = "~> 1.6"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 1.9"
    }
    
    helm = {      
      source  = "hashicorp/helm"
      version = "1.1.1"
    }
  }

}
