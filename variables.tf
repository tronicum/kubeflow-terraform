
variable environment {
  type = string
}

variable project {
  type = string
}

variable root_domain {
  type = string
}

variable create_route_53_subdomain {
  type = bool
  default = true
}



variable domain {
  type = string
}


variable vpc_id {
  type = string
  description = "The ID of an existing VPC to reuse"
  default = null
}

variable private_subnets {
  type = list
  description = "A list of private subnets within the existing VPC"
  default = null
}


variable aws_account {
  type = string
}

variable cluster_name {
  type = string
}

variable aws_region {
  type = string
}
variable argocd_branch {
  type = string
}

variable argocd_path_prefix {
  type = string
  default = ""
}

variable argocd_apps_dir {
  type    = string  
  default = "apps"
}

variable argocd_repo_url {
  type = string
  default = ""
}

variable argocd_repo_ssh_private_key {
  type = string
  default = ""
}

variable kubeflow_manifests_branch {
  type = string
}

variable kubeflow_manifests_release {
  type = string
}

variable db_names {
  type = map(string)
}


variable kubeflow_cognito_groups {
  type = string
}

variable kubeflow_profiles {
  type = list
}

variable kubeflow_cognito_users {
  type = list
}

variable aws_private {
  type = bool
  default = false
}

variable aws_auth_user_mapping {
  type = list
}

variable aws_auth_role_mapping {
  type = list
}

variable cert_manager_email {
  type = string
}

variable kubernetes_version {
  type = string
}

variable cognito_callback_prefix_kubeflow {
  type = string
  default = "kubeflow"
}

variable cognito_callback_prefix_argocd {
  type = string
  default = "argocd"
}

variable availability_zones {
  type = list
}

variable kube2iam_role_arn {
  type = string
}
variable tags {
  type = map(string)
}

variable "rds_database_name" {
  type        = string
  description = "Database name"
  default     = "exampledb"
}

variable "rds_database_multi_az" {
  type        = bool
  description = "Enabled multi_az for RDS"
  default     = "true"
}

variable "rds_database_engine" {
  type        = string
  description = "What server use? postgres | mysql | oracle-ee | sqlserver-ex"
  default     = "postgres"
}

variable "rds_database_engine_version" {
  type        = string
  description = "Engine version"
  default     = "9.6.9"
}

variable "rds_database_major_engine_version" {
  type        = string
  description = "Major Database engine version"
}

variable "rds_database_instance" {
  type        = string
  description = "RDS instance type"
  default     = "db.t3.large"
}

variable "rds_database_username" {
  type        = string
  description = "Database username"
  default     = "sa"
}

variable "rds_database_password" {
  type        = string
  description = "Database password"
  default     = ""
}

variable "rds_kms_key_id" {
  type        = string
  description = "Id of kms key for encrypt database"
  default     = ""
}

variable "rds_allocated_storage" {
  type        = string
  description = "Database storage in GB"
  default     = "10"
}

variable "rds_storage_encrypted" {
  type        = string
  description = "Database must be encrypted?"
  default     = "false"
}

variable "rds_maintenance_window" {
  type        = string
  description = "The window to perform maintenance in. Syntax: 'ddd:hh24:mi-ddd:hh24:mi'"
  default     = "Mon:00:00-Mon:03:00"
}

variable "rds_backup_window" {
  type        = string
  description = ""
  default     = "03:00-06:00"
}

variable "rds_port_mapping" {
  description = "mapping port for engine type"
  default = {
    "postgres"     = "5432",
    "sqlserver-ex" = "1433",
    "mysql"        = "3306",
    "oracle-ee"    = "1521"
  }
}

variable "rds_database_delete_protection" {
  type        = bool
  description = "enabled delete protection for database"
  default     = "false"
}

variable "rds_database_tags" {
  default     = {}
  description = "Additional tags for rds instance"
  type        = map(string)
}



variable "rds_iam_database_authentication_enabled" {
  default     = false
  description = "Set to true to authenticate to RDS using an IAM role"
  type        = bool
}


variable "rds_enabled_cloudwatch_logs_exports" {
  default     = []
  description = "List of cloudwatch log types to enable"
  type        = list(string)
}
variable "rds_instance_name" {
  description = "Name of the RDS instance"
  type        = string
}


variable "rds_publicly_accessible" {
  description = "Set to true to enable accessing the RDS DB from outside the VPC"
  default = false
  type    = bool
}