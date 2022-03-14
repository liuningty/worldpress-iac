# Secret
resource "kubernetes_secret" "mysql-pass" {
  metadata {
    name      = "mysql-pass"
  }
  data = {
    password = "4oCYdGVzdDEyM+KAmQ=="
  }
  type = "Opaque"
}

# Create NFS export using Ansible
resource "null_resource" "mysql-nfs" {
  provisioner "local-exec" {
    command = "ansible-playbook ./ansible_templates/create_isilon_nfs.yaml"
  }
  provisioner "local-exec" {
    when = destroy
    command = "ansible-playbook ./ansible_templates/delete_isilon_nfs.yaml"
  }
}

# Peristent volume
resource "kubernetes_persistent_volume" "mysql-pv" {
  depends_on = [null_resource.mysql-nfs]
  metadata {
    name = "mysql-pv"
  }
  spec {
    capacity = {
      storage = "3Gi"
    }
    storage_class_name = "standard"
    access_modes       = ["ReadWriteMany"]
    persistent_volume_source {
      nfs {
        server = "192.168.117.72"
        path   = "/ifs/mysql-nfs"
      }
    }
  }
}

# Peristent volume Claim
resource "kubernetes_persistent_volume_claim" "mysql-pv-claim" {
  metadata {
    name = "mysql-pv-claim"
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "3Gi"
      }
    }
    volume_name        = kubernetes_persistent_volume.mysql-pv.metadata[0].name
    storage_class_name = "standard"
  }
}

# Deployment
resource "kubernetes_deployment" "wordpress-mysql" {
  metadata {
    name = "wordpress-mysql"
    labels = {
      App = "wordpress-mysql"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        App = "wordpress-mysql"
      }
    }
    template {
      metadata {
        labels = {
          App = "wordpress-mysql"
        }
      }
      spec {
        container {
          image = "mysql:5.6"
          name  = "mysql"
          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql-pass.metadata[0].name
                key = "password"
              }
            }
          }
          port {
            container_port = 3306
          }

          volume_mount {
            mount_path = "/var/lib/mysql"
            name       = "mysql-persistent-storage"
          }
        }
        volume {
          name = "mysql-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mysql-pv-claim.metadata[0].name
          }
        }
      }
    }
  }
  timeouts {
    create = "5m"
  }
}

# Service
resource "kubernetes_service" "wordpress-mysql" {
  metadata {
    name = "wordpress-mysql"
  }
  spec {
    selector = {
      App = kubernetes_deployment.wordpress-mysql.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port = 3306
    }
    cluster_ip = "None"
  }
}
