data "aws_caller_identity" "current" {}


data "aws_route53_zone" "kubeflow_zone" {  
    name         = local.root_domain
    private_zone = false
}


locals {
  aws_account = data.aws_caller_identity.current.account_id
  aws_region = "eu-central-1"
  environment = "dev"
  project = var.project_branch
  root_domain = "my-domain.com"
  domain = "${local.environment}-${local.project}.${local.root_domain}"

  db_names = {
      "cache" = "cachedb"
      "pipelines" = "mlpipeline"
      "metadata" = "metadb"
      "mlflow" = "mlflow"
      "katib" = "katib"
  }

  kubeflow_profiles =  [
      {
          email     = "my.name@alexanderthamm.com"
          namespace = "my-name"
      },
      {
          email     = "your.name@alexanderthamm.com"
          namespace = "your-name"
      }
  ]

  argocd_branch = "${local.aws_account}/${local.environment}-${local.project}.${local.root_domain}"   

  tags = {
      "env": local.environment
      "project": local.project
  }

}
module kubeflow {
  source = "git::https://github.com/at-gmbh/kubeflow-terraform.git?ref=v1.2.0-at-1.0.0"

  aws_region = local.aws_region
    
  environment = local.environment
  project = local.project

  // the full domain to roll out to
  root_domain = local.root_domain
  domain = local.domain
  aws_account = local.aws_account

  // the name of the EKS cluster to roll out
  cluster_name = "${local.environment}-${local.project}"

  // argocd GitOps repo
  argocd_owner      = "my-github-project"
  argocd_repository = "kubeflow-argocd"
  argocd_branch     =  local.argocd_branch
  argocd_path_prefix = "argocd/"
  argocd_apps_dir    = "applications"

  // kubeflow manifests:
  kubeflow_manifests_branch = "v1.2-branch-at-0.2"
  kubeflow_manifests_release = "v1.2.0-at-0.2"


  // the names of the various MySQL databases that Kubeflow needs. These will automatically be created one the same RDS instance.
  db_names = local.db_names

  // These uses will be added to the Cognito User pool
  kubeflow_profiles = local.kubeflow_profiles


  // The name of the cognito user pool that users will be added to
  // TODO, this currently has no effect
  kubeflow_cognito_groups = "default"
  

 // format "kubeflow_profiles" into inputs needed to create Cognito users
  kubeflow_cognito_users = [for kubeflow_profile in local.kubeflow_profiles :
        {
          username = kubeflow_profile.email
          email = kubeflow_profile.email
          group = "default"
          user_hash = sha1("user@${kubeflow_profile.email}") //needed for cloudformation template
          user_group_hash = sha1("user-group@${kubeflow_profile.email}") //needed for cloudformation template
        }
    ]

  // tags that will be added by default to all AWS resources
  tags = local.tags

  // Main route53 zone id if exists 
  mainzoneid = data.aws_route53_zone.kubeflow_zone.zone_id

  // Use private zone
  aws_private = "false"

  // Names of domains aimed for endpoints
  domains = [local.domain]

  // ARNs of IAM users who will have Kubernetes admin permissions.
  aws_auth_user_mapping = [
      {
          userarn  = "arn:aws:iam::${local.aws_account}:user/kubernetes-user"
          username = "kubernetes-user"
          groups   = ["system:masters"]
      }
  ]

  // ARNs of IAM roles that will have Kubernetes admin permissions.
  aws_auth_role_mapping = [
      {
          rolearn  = "arn:aws:iam::${local.aws_account}:role/kubernetes-role"
          username = "kubernetes-role"
          groups   = ["system:masters"]
      }
  ]

  // Email that would be used for LetsEncrypt notifications
  cert_manager_email = "karl.schriek@alexanderthamm.com"

  // Kubernetes version to roll oout
  kubernetes_version = "1.18"

  // where the Kubeflow Dashboard and the ArgoCD dashboard can be accessed (e.g. kubeflow.my-platform.my-domain.com, argocd.my-platform.my-domain.com)
  cognito_callback_prefix_kubeflow = "kubeflow"
  cognito_callback_prefix_argocd = "argocd" 


  // Availability zones of the worker nodes in the EKS cluster
  availability_zones = ["${local.aws_region}a", "${local.aws_region}b"]


  // Role that will be attached to kube2iam daemonsets. This role must be able to assume whatever roles you wish individual pods to assume
  kube2iam_role_arn = "arn:aws:iam::${local.aws_account}:role/kubernetes-role"


  // rds params
  rds_publicly_accessible = true
  rds_database_name = "mydb"
  rds_instance_name = "${local.environment}-${local.project}-instance"
  rds_database_multi_az = false
  rds_database_engine = "mysql"
  rds_database_major_engine_version = "5.7"
  rds_database_engine_version = "5.7.31"
  rds_database_instance = "db.t2.micro"
  rds_iam_database_authentication_enabled = false
  rds_allocated_storage = 20
  rds_storage_encrypted = false
  rds_database_delete_protection = false
  rds_enabled_cloudwatch_logs_exports = []
  rds_database_tags = local.tags
  

}
