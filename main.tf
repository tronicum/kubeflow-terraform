
module network {
  source             = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/network?ref=v1.0.0"
  availability_zones = var.availability_zones
  environment        = var.environment
  project            = var.project
  cluster_name       = var.cluster_name
  tags               = var.tags
}


// Worker additional policy (to allow read/write access to S3 bucket for Pipelines)
resource "aws_iam_policy" "worker_group_policy" {
  name        = "${var.cluster_name}-worker-policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListObjectsInBucket",
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": ["${module.s3.s3_bucket_arn}"]
        },
        {
            "Sid": "AllObjectActions",
            "Effect": "Allow",
            "Action": "s3:*Object",
            "Resource": ["${module.s3.s3_bucket_arn}/*"]
        }
    ]
}
EOF
}

// Kubernetes Cluster
module kubernetes {
  source             = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/kubernetes?ref=v1.0.0"
  availability_zones = var.availability_zones
  environment        = var.environment
  project            = var.project
  cluster_name       = var.cluster_name
  cluster_version    = var.kubernetes_version
  vpc_id             = module.network.vpc_id
  subnets            = module.network.private_subnets
  aws_auth_user_mapping    = var.aws_auth_user_mapping
  aws_auth_role_mapping    = var.aws_auth_role_mapping
  wait_for_cluster_interpreter = ["/bin/bash", "-c"]

  workers_additional_policies = [aws_iam_policy.worker_group_policy.arn]
  
  //spot
  spot_max_cluster_size  = 5
  spot_min_cluster_size  = 0
  spot_desired_capacity  = 0
  spot_instance_type  = ["m5.large", "m5.xlarge", "m5.2xlarge"]
  spot_instance_pools  = 10
  spot_asg_recreate_on_change  = false
  spot_allocation_strategy  = "lowest-price"
  spot_max_price  = ""

  //common
  on_demand_common_max_cluster_size  = 5
  on_demand_common_min_cluster_size  = 0
  on_demand_common_desired_capacity  = 1
  on_demand_common_instance_type  =  ["m5.large", "m5.xlarge", "m5.2xlarge"]
  on_demand_common_allocation_strategy  = "prioritized"
  on_demand_common_base_capacity  = 0
  on_demand_common_percentage_above_base_capacity  = 0
  on_demand_common_asg_recreate_on_change  = false
  
  //cpu
  on_demand_cpu_max_cluster_size  =  5
  on_demand_cpu_min_cluster_size  =  0
  on_demand_cpu_desired_capacity  =  0
  on_demand_cpu_instance_type  =  ["c5.xlarge", "c5.2xlarge", "c5n.xlarge"]
  on_demand_cpu_allocation_strategy  =  "prioritized"
  on_demand_cpu_base_capacity  =  0
  on_demand_cpu_percentage_above_base_capacity  =  0
  on_demand_cpu_asg_recreate_on_change  =  false

  //gpu
  on_demand_gpu_max_cluster_size  = 5
  on_demand_gpu_min_cluster_size  = 0
  on_demand_gpu_desired_capacity  = 0
  on_demand_gpu_instance_type  = ["p2.xlarge", "g4dn.xlarge", "p3.2xlarge"]
  on_demand_gpu_allocation_strategy  = "prioritized"
  on_demand_gpu_base_capacity  =  0
  on_demand_gpu_percentage_above_base_capacity  =  0
  on_demand_gpu_asg_recreate_on_change  =  false

  tags = var.tags

}



module acm {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> v2.0"

  domain_name               = var.domains[0]
  subject_alternative_names = ["*.${var.domains[0]}"]
  zone_id                   = module.external_dns.zone_id
  validate_certificate      = var.aws_private == "false" ? true : false
  tags                      = var.tags
}


// Create Cognito User Pool
module cognito {
  source       = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/cognito/user-pool?ref=v1.0.0"
  domain       = var.domain //TODO make "auth" parameterisable? Currently it is hardcode in the "cognito" module
  zone_id      = module.external_dns.zone_id
  cluster_name = module.kubernetes.cluster_name
  tags         = var.tags
  invite_template = {
    email_subject = "You've been invited to https://${var.cognito_callback_prefix_kubeflow}.${var.domain}"
    email_message = <<EOT
Hi {username}, welcome to https://${var.cognito_callback_prefix_kubeflow}.${var.domain}. Your temporary password is {####}
EOT
    sms_message   = <<EOT
Hi {username}, you have been invited to access Alexander Thamm's Kubeflow cluster. Your temporary password is {####}
EOT
  }
}

// Create Cognito User Pool Client (Kubeflow)
resource aws_cognito_user_pool_client kubeflow {
  name                                 = "kubeflow"
  user_pool_id                         = module.cognito.pool_id
  callback_urls                        = ["https://${var.cognito_callback_prefix_kubeflow}.${var.domains[0]}/oauth2/idpresponse"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]
  allowed_oauth_flows                  = ["code"]
  supported_identity_providers         = ["COGNITO"]
  generate_secret                      = true

}

// Create Cognito User Pool Client (ArgoCD)
resource aws_cognito_user_pool_client argocd {
  //TODO shouldn't this go to a separate user pool?
  name                                 = "argocd"
  user_pool_id                         = module.cognito.pool_id
  callback_urls                        = ["https://${var.cognito_callback_prefix_argocd}.${var.domains[0]}/auth/callback"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "profile", "email"]
  allowed_oauth_flows                  = ["code"]
  supported_identity_providers         = ["COGNITO"]
  generate_secret                      = true

}


// Create Cognito Users
module cognito_users {
  source = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/cognito/users?ref=v1.0.0"
  cloudformation_stack_name = "${var.cluster_name}-cognito-users"
  pool_id  = module.cognito.pool_id
  user_groups = ["default"] //TODO
  users = var.kubeflow_cognito_users
  tags = var.tags
}


// Create RDS instance
module "rds" {
  source  = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/rds?ref=v1.0.0"

  environment  = var.environment
  project      = var.project
  cluster_name = module.kubernetes.cluster_name

  vpc_id = module.network.vpc.vpc_id
  subnets =  module.network.vpc.private_subnets
  worker_security_group_id = module.kubernetes.worker_security_group_id

  
  rds_publicly_accessible = var.rds_publicly_accessible
  rds_database_name = var.rds_database_name
  rds_instance_name = var.rds_instance_name
  rds_database_multi_az = var.rds_database_multi_az
  rds_database_engine = var.rds_database_engine
  rds_database_major_engine_version = var.rds_database_major_engine_version
  rds_database_engine_version = var.rds_database_engine_version
  rds_database_instance = var.rds_database_instance
  rds_iam_database_authentication_enabled = var.rds_iam_database_authentication_enabled
  rds_allocated_storage = var.rds_allocated_storage
  rds_storage_encrypted = var.rds_storage_encrypted
  rds_database_delete_protection = var.rds_database_delete_protection
  rds_enabled_cloudwatch_logs_exports = var.rds_enabled_cloudwatch_logs_exports
  rds_database_tags = var.rds_database_tags
}



// Create S3 bucket
module "s3" {
  source            = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/storage/s3?ref=v1.0.0"
  module_depends_on = []
  s3_bucket_name    = "${var.aws_account}-${var.cluster_name}-kubeflow"
  cluster_name      = var.cluster_name
  tags              = var.tags
  trusted_role_arns = [var.kube2iam_role_arn]
}





////  Kubernetes Resources


// AWS Storage ConfigMaps and Secrets
module "aws_storage" {
  source = "./modules/aws-storage-configs"

  s3_bucket_name = module.s3.s3_bucket_name
  cluster_name = var.cluster_name
  aws_region = var.aws_region
  db_names = var.db_names

  rds_host = module.rds.this_db_instance_address
  rds_port = module.rds.this_db_instance_port
  rds_username = module.rds.this_db_instance_username
  rds_password = module.rds.this_db_instance_password

  namespaces = join(",",[for profile in var.kubeflow_profiles: profile.namespace])

  role_to_assume_arn = module.s3.s3_role_arn
  s3_user_access_key = module.s3.s3_user_access_key
}



//this is used to "reflect" secrets and config maps. We need this work secrets/configs that are needed in each user namespace
resource helm_release "reflector" {
  depends_on = [module.kubernetes]

  name          = "reflector"
  repository    = "https://emberstack.github.io/helm-charts"
  chart         = "reflector"
  version       = "5.4.17"
  namespace     = "kube-system"
  recreate_pods = true
  timeout       = 1200
}



// Namespace for knative-serving
resource "kubernetes_namespace" "knative-serving" {
  metadata {
    labels = {
      "serving.knative.dev/release": "v0.14.3"
    }
    name = "knative-serving"
  }
}


// knative configmap to point to correct domain
resource "kubernetes_config_map" "knative_config_map" {
  metadata {
    name = "config-domain"
    namespace = "knative-serving"
    labels = {
      "serving.knative.dev/release" = "v0.14.3"
    }
  }
  data = {
    (var.domain) = ""
  }
}

// knative configmap to point to use corret domainTemplate
resource "kubernetes_config_map" "knative_network_config_map" {
  metadata {
    name = "config-network"
    namespace = "knative-serving"
    labels = {
      "serving.knative.dev/release" = "v0.14.3"
    }
  }
  data = {
    "domainTemplate" = "{{.Name}}-{{.Namespace}}.{{.Domain}}"
  }
}

// ArgoCD
module argocd {
  source        = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/cicd/argo-cd?ref=v1.0.0"
  module_depends_on = [module.kubernetes]
  branch        = var.argocd_branch
  owner         = var.argocd_owner
  repository    = var.argocd_repository
  cluster_name  = module.kubernetes.cluster_name
  domains       = var.domains
  chart_version = "2.7.4"
  oidc = {
    secret = aws_cognito_user_pool_client.argocd.client_secret
    pool   = module.cognito.pool_id
    name   = "Cognito"
    id     = aws_cognito_user_pool_client.argocd.id
  }
  ingress_annotations = {
    "kubernetes.io/ingress.class"               = "alb"
    "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
    "alb.ingress.kubernetes.io/certificate-arn" = module.acm.this_acm_certificate_arn
    "alb.ingress.kubernetes.io/listen-ports" = jsonencode(
      [{ "HTTPS" = 443 }]
    )
  }
  path_prefix = var.argocd_path_prefix
  apps_dir    = var.argocd_apps_dir
  tags        = var.tags
}



//// Kubernetes YAML Specs for Applications managed by ArgoCD

// Create YAML specs for MLFLow
module mlflow {
  source = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/mlflow?ref=v1.0.0"
  argocd = module.argocd.state
}

// Create YAML specs for Kubeflow Profiles
module profiles {
  source = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/kubeflow-profiles?ref=v1.0.0"
  argocd = module.argocd.state
  profiles = var.kubeflow_profiles
}

// Create YAML specs for kube2iam
module kube2iam {
  source = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/system/kube2iam?ref=v1.0.0"
  argocd = module.argocd.state
  base_role_arn = var.kube2iam_role_arn
}

// Create YAML specs for KFServing
module kfserving {
  source = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/kfserving/0-3-0/?ref=v1.0.0"
  argocd = module.argocd.state
}



// Create YAML specs for Kubeflow Operator and KFDef
module kubeflow {
  source = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/kubeflow-operator?ref=v1.0.0"
  ingress_annotations = {
    "kubernetes.io/ingress.class"               = "alb"
    "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
    "alb.ingress.kubernetes.io/certificate-arn" = module.acm.this_acm_certificate_arn
    "alb.ingress.kubernetes.io/auth-type"       = "cognito"
    "alb.ingress.kubernetes.io/auth-idp-cognito" = jsonencode({
      "UserPoolArn"      = module.cognito.pool_arn
      "UserPoolClientId" = aws_cognito_user_pool_client.kubeflow.id
      "UserPoolDomain"   = module.cognito.domain
    })
    "alb.ingress.kubernetes.io/listen-ports" = jsonencode(
      [{ "HTTPS" = 443 }]
    )
  }
  domain = "kubeflow.${var.domains[0]}"
  argocd = module.argocd.state


  repository = "https://github.com/at-gmbh/kubeflow-manifests"
  ref        =  var.kubeflow_manifests_branch
  kfdef = <<EOT
apiVersion: kfdef.apps.kubeflow.org/v1
kind: KfDef
metadata:
  namespace: kubeflow
  name: kubeflow
spec:
  applications:
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: namespaces/base
      name: namespaces
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: stacks/aws/application/istio-stack
      name: istio-stack
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: stacks/aws/application/cluster-local-gateway
      name: cluster-local-gateway
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: stacks/aws/application/istio
      name: istio
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: application/v3
      name: application
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: metacontroller/base
      name: metacontroller
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: admission-webhook/bootstrap/overlays/application
      name: bootstrap
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: spark/spark-operator/overlays/application
      name: spark-operator
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: knative/installs/generic
      name: knative
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: stacks/aws/application/spartakus
      name: spartakus
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: stacks/aws
      name: kubeflow-apps
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: stacks/aws/application/istio-ingress-cognito
      name: istio-ingress
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: aws/aws-istio-authz-adaptor/base_v3
      name: aws-istio-authz-adaptor
  repos:
    - name: manifests
      uri: 'https://github.com/at-gmbh/manifests/archive/${var.kubeflow_manifests_release}.tar.gz'
  version: ${var.kubeflow_manifests_branch}
EOT
 
}

// Create YAML specs for Cluster Autoscaler
module cluster_autoscaler {
  source            = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/system/cluster-autoscaler?ref=v1.0.0"
  image_tag         = "v1.15.7"
  cluster_name      = module.kubernetes.cluster_name
  module_depends_on = [module.kubernetes]
  argocd            = module.argocd.state
  tags              = var.tags
}

// Create YAML specs for Certificate Manager
module cert_manager {
  module_depends_on = [module.kubernetes]
  source            = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/system/cert-manager?ref=v1.0.0"
  cluster_name      = module.kubernetes.cluster_name
  domains           = var.domains
  vpc_id            = module.network.vpc_id
  environment       = var.environment
  project           = var.project
  zone_id           = module.external_dns.zone_id
  email             = var.cert_manager_email
  argocd            = module.argocd.state
}


// Create YAML specs for ALB Ingress
module alb_ingress {
  module_depends_on = [module.kubernetes]
  source            = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/ingress/aws-alb?ref=v1.0.0"
  cluster_name      = module.kubernetes.cluster_name
  domains           = var.domains
  vpc_id            = module.network.vpc_id
  certificates_arns = [module.acm.this_acm_certificate_arn]
  argocd            = module.argocd.state
}

// Create YAML specs for External DNS
module external_dns {
  source       = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/system/external-dns?ref=v1.0.0"
  cluster_name = module.kubernetes.cluster_name
  vpc_id       = module.network.vpc_id
  aws_private  = var.aws_private
  hostedzones  = var.domains
  mainzoneid   = var.mainzoneid
  argocd       = module.argocd.state
  tags         = var.tags
}