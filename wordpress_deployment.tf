# Peristent volume Claim
resource "kubernetes_persistent_volume_claim" "wp-pv-claim" {
  metadata {
    name = "wp-pv-claim"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
    storage_class_name = "isilon"
  }
}

# Deployment
resource "kubernetes_deployment" "wordpress" {
  depends_on = [kubernetes_deployment.wordpress-mysql]
  metadata {
    name = "wordpress"
    labels = {
      App = "wordpress"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        App = "wordpress"
      }
    }
    template {
      metadata {
        labels = {
          App = "wordpress"
        }
      }
      spec {
        container {
          image = "wordpress:4.8-apache"
          name  = "wordpress"
          env {
            name = "WORDPRESS_DB_HOST"
            value = "wordpress-mysql"
          }
          env {
            name = "WORDPRESS_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql-pass.metadata[0].name
                key = "password"
              }
            }
          }
          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
          volume_mount {
            mount_path = "/var/www/html"
            name       = "wordpress-persistent-storage"
          }
        }
        volume {
          name = "wordpress-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.wp-pv-claim.metadata[0].name
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "wordpress" {
  metadata {
    name = "wordpress"
  }
  spec {
    selector = {
      App = kubernetes_deployment.wordpress.spec.0.template.0.metadata[0].labels.App
    }
    port {
      node_port   = 30008
      port        = 80
      target_port = 80
    }

    type = "NodePort"
  }
}
