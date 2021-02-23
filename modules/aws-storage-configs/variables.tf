
variable s3_bucket_name {
  type = string
}


variable cluster_name {
  type = string
}

variable aws_region {
  type = string
}

variable db_names {
  type = map(string)
}


variable rds_host {
  type = string
}

variable rds_port {
  type = string
}

variable rds_username {
  type = string
}

variable rds_password {
  type = string
}

variable namespaces {
  type = string
}

variable role_to_assume_arn {
  type = string
}

variable s3_user_access_key {
  type = map(string)
  default = {
    id: "" 
    secret: ""
  }
}

variable module_depends_on {
  type = list
  default = []
}