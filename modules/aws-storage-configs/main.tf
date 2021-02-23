
resource "kubernetes_namespace" "mlflow" {
  depends_on = [var.module_depends_on]

  metadata {
    labels = {
        "control-plane"   = "kubeflow"
        "istio-injection" = "enabled"
    }

    name = "mlflow"
  }
}

resource "kubernetes_namespace" "kubeflow" {
  depends_on = [var.module_depends_on]

  metadata {
    labels = {
        "control-plane"   = "kubeflow"
        "istio-injection" = "enabled"
    }
    name = "kubeflow"
  }
}


resource "kubernetes_namespace" "pipelines" {
  depends_on = [var.module_depends_on]

  metadata {
    labels = {
        "control-plane"   = "kubeflow"
        "istio-injection" = "enabled"
    }
    name = "pipelines"
  }
}


resource "kubernetes_secret" "aws_storage_secret" {

  depends_on = [kubernetes_namespace.mlflow, kubernetes_namespace.kubeflow]

  for_each = toset(["mlflow", "kubeflow"])

  metadata {
    name = "aws-storage-secret"
    namespace = each.key
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed" = "true"
      "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces" = var.namespaces #this configmap can be reflected in (copied to) these namespaces
    }
  }

  data = { 
    "username" = var.rds_username
    "password" = var.rds_password
    
    "accesskey" = var.s3_user_access_key.id
    "secretkey" = var.s3_user_access_key.secret

    "rds_host" = var.rds_host
    "rds_port" = var.rds_port
    "rds_username" = var.rds_username
    "rds_password" = var.rds_password

    "s3_bucket" = var.s3_bucket_name
    "s3_region" = var.aws_region
    "s3_access_key" = var.s3_user_access_key.id
    "s3_secret_key" = var.s3_user_access_key.secret
    
    "db_name_cache" = var.db_names.cache
    "db_name_pipelines" = var.db_names.pipelines
    "db_name_metadata" = var.db_names.metadata
    "db_name_mlflow" = var.db_names.mlflow
    "db_name_katib" = var.db_names.katib
  }

  type = "kubernetes.io/basic-auth"
}


resource "kubernetes_config_map" "aws_storage_workflow_controller_config" {
  depends_on = [kubernetes_namespace.mlflow, kubernetes_namespace.kubeflow]


  metadata {
    name = "aws-storage-workflow-controller-config"
    namespace = "kubeflow"
  }

  data = { 
    "config" = <<EOT
{
executorImage: gcr.io/ml-pipeline/argoexec:v2.7.5-license-compliance,
containerRuntimeExecutor: docker,
workflowDefaults:
{
     metadata: {annotations: {"iam.amazonaws.com/role": "${var.role_to_assume_arn}"}}
},
artifactRepository:
{
    archiveLogs: true,
    s3: {
        bucket: "${var.s3_bucket_name}",
        keyPrefix: artifacts,
        endpoint: s3.amazonaws.com,
        insecure: false,
        region: "${var.aws_region}",
        useSDKCreds: true
    }
  }
}  
EOT

  }

}



resource "kubernetes_config_map" "aws_storage_ml_pipeline_config" {
  depends_on = [kubernetes_namespace.mlflow, kubernetes_namespace.kubeflow]

  metadata {
    name = "aws-storage-ml-pipeline-config"
    namespace = "kubeflow"
  }

  data = { 
  "config.json" = <<EOT
{
  "DBConfig": {
    "Host": "${var.rds_host}",
    "Port": "${var.rds_port}",
    "DriverName": "mysql",
    "DataSourceName": "",
    "DBName": "${var.db_names.pipelines}",
    "GroupConcatMaxLen": 4194304
  },
  "ObjectStoreConfig": {
    "Host": "s3.amazonaws.com",
    "Region": "${var.aws_region}",
    "Secure": true,
    "BucketName": "${var.s3_bucket_name}",
    "PipelineFolder": "pipelines",
    "PipelinePath": "pipelines",
    "AccessKey": "",
    "SecretAccessKey": ""
  },
  "InitConnectionTimeout": "6m",
  "DefaultPipelineRunnerServiceAccount": "pipeline-runner"
}
EOT
"sample_config.json" = <<EOT
[
  {
    "name": "[Demo] XGBoost - Training with Confusion Matrix",
    "description": "[source code](https://github.com/kubeflow/pipelines/blob/master/samples/core/xgboost_training_cm) [GCP Permission requirements](https://github.com/kubeflow/pipelines/blob/master/samples/core/xgboost_training_cm#requirements). A trainer that does end-to-end distributed training for XGBoost models.",
    "file": "/samples/core/xgboost_training_cm/xgboost_training_cm.py.yaml"
  },
  {
    "name": "[Demo] TFX - Taxi Tip Prediction Model Trainer",
    "description": "[source code](https://console.cloud.google.com/mlengine/notebooks/deploy-notebook?q=download_url%3Dhttps%253A%252F%252Fraw.githubusercontent.com%252Fkubeflow%252Fpipelines%252Fmaster%252Fsamples%252Fcore%252Fparameterized_tfx_oss%252Ftaxi_pipeline_notebook.ipynb) [GCP Permission requirements](https://github.com/kubeflow/pipelines/blob/master/samples/contrib/parameterized_tfx_oss#permission). Example pipeline that does classification with model analysis based on a public tax cab dataset.",
    "file": "/samples/core/parameterized_tfx_oss/parameterized_tfx_oss.py.yaml"
  },
  {
    "name": "[Tutorial] Data passing in python components",
    "description": "[source code](https://github.com/kubeflow/pipelines/tree/master/samples/tutorials/Data%20passing%20in%20python%20components) Shows how to pass data between python components.",
    "file": "/samples/tutorials/Data passing in python components/Data passing in python components - Files.py.yaml"
  },
  {
    "name": "[Tutorial] DSL - Control structures",
    "description": "[source code](https://github.com/kubeflow/pipelines/tree/master/samples/tutorials/DSL%20-%20Control%20structures) Shows how to use conditional execution and exit handlers. This pipeline will randomly fail to demonstrate that the exit handler gets executed even in case of failure.",
    "file": "/samples/tutorials/DSL - Control structures/DSL - Control structures.py.yaml"
  }
]
EOT
  }
}




resource "kubernetes_config_map" "aws_storage_ml_pipeline_ui_config" {
  depends_on = [kubernetes_namespace.mlflow, kubernetes_namespace.kubeflow]

  metadata {
    name = "aws-storage-ml-pipeline-ui-config"
    namespace = "kubeflow"
  }

  data = { 
  "viewer-pod-template.json" = <<EOT
{
  "spec": {
      "containers": [
        {
          "env": [
            {
              "name": "AWS_ACCESS_KEY_ID",
              "valueFrom": {
                "secretKeyRef": {
                  "name": "aws-storage-secret",
                  "key": "s3_access_key"
                }
              }
            },
            {
              "name": "AWS_SECRET_ACCESS_KEY",
              "valueFrom": {
                "secretKeyRef": {
                  "name": "aws-storage-secret",
                  "key": "s3_secret_key"
                }
              }
            },
            {
              "name": "AWS_REGION",
              "valueFrom": {
                "secretKeyRef": {
                  "name": "aws-storage-secret",
                  "key": "s3_region"
                }
              }
            }
          ]
        }
      ]
    }
}
EOT
  }
}





resource "kubernetes_config_map" "aws_storage_ml_pipeline_ui_viewer_template" {
  depends_on = [kubernetes_namespace.mlflow, kubernetes_namespace.kubeflow]

  metadata {
    name = "aws-storage-ml-pipeline-viewer-template"
    namespace = "kubeflow"
  }

  data = { 
  "viewer-tensorboard-template.json" = <<EOT

  {
        "metadata": {
            "annotations": {
                iam.amazonaws.com/role: "${var.role_to_assume_arn}"
            }
        },
        "spec": {
            "containers": [
                {
                    "env": [
                        {
                            "name": "AWS_REGION",
                            "value": "${var.aws_region}"
                        }
                    ]
                }
            ]
        }
    }
EOT
  }
}



resource kubernetes_job create_databases {

  depends_on = [kubernetes_secret.aws_storage_secret]

  for_each = {
    (var.db_names.mlflow) = "mlflow"
    (var.db_names.pipelines) ="kubeflow"
    (var.db_names.metadata) = "kubeflow"
    (var.db_names.cache) = "kubeflow"
    (var.db_names.katib) = "kubeflow"
  }

  metadata {
    name = "create-${each.key}-database"
    namespace = each.value
  }
  spec {
    template {
      metadata {
        annotations = {
            "sidecar.istio.io/inject": "false"
          }
      }

      spec {
        container {
          name    = "create-${each.key}-database"
          image   = "kschriek/mysql-db-creator"
          env {
              name = "HOST"
              value_from {
                secret_key_ref {
                  name = "aws-storage-secret"
                  key = "rds_host"
                }
              }
            }
          env  {
              name = "PORT"
              value_from {
                secret_key_ref {
                  name = "aws-storage-secret"
                  key = "rds_port"
                }
              }
            }
          env {
              name = "USERNAME"
              value_from {
                secret_key_ref {
                  name = "aws-storage-secret"
                  key = "rds_username"
                }
              }
            }
          env {
              name = "PASSWORD"
              value_from {
                secret_key_ref {
                  name = "aws-storage-secret"
                  key = "rds_password"
                }
              }
            }
          env {
              name = "DATABASE"
              value = each.key
            }          
        }
        restart_policy = "Never"
      }
    }
    backoff_limit = 4
  }

}