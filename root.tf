terraform {
  required_version = "0.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.29.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "1.11.1"
    }    
    helm = {      
      source  = "hashicorp/helm"
      version = "1.1.1"
    }
  }

}
