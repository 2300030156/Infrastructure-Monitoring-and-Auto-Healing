terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

resource "google_compute_network" "vpc" {
  name                    = "autoheal-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "autoheal-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_firewall" "allow_5000" {
  name    = "allow-tcp-5000"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-http"]
}

resource "google_compute_health_check" "app_hc" {
  name                = "app-health-check"
  check_interval_sec  = 2
  timeout_sec         = 1
  healthy_threshold   = 1
  unhealthy_threshold = 3

  http_health_check {
    port         = 5000
    request_path = "/health"
  }
}

resource "google_compute_instance_template" "app_template" {
  name_prefix  = "autoheal-template-"
  machine_type = "e2-medium"
  tags         = ["allow-http"]

  disk {
    source_image = "projects/debian-cloud/global/images/family/debian-11"
    boot         = true
    auto_delete  = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id

    access_config {}
  }

  metadata_startup_script = replace(file("${path.module}/startup_script.sh"), "\r\n", "\n")

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "app_mig" {
  name               = "autoheal-mig"
  base_instance_name = "autoheal-app"
  region             = var.region
  target_size        = 2

  version {
    instance_template = google_compute_instance_template.app_template.id
  }

  named_port {
    name = "http"
    port = 5000
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.app_hc.id
    initial_delay_sec = 10
  }
}

resource "google_compute_backend_service" "app_backend" {
  name                  = "autoheal-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.app_hc.id]

  backend {
    group           = google_compute_region_instance_group_manager.app_mig.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_url_map" "app_url_map" {
  name            = "autoheal-url-map"
  default_service = google_compute_backend_service.app_backend.id
}

resource "google_compute_target_http_proxy" "app_proxy" {
  name    = "autoheal-http-proxy"
  url_map = google_compute_url_map.app_url_map.id
}

resource "google_compute_global_forwarding_rule" "app_fwd" {
  name                  = "autoheal-http-rule"
  target                = google_compute_target_http_proxy.app_proxy.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
}

output "load_balancer_ip" {
  value = google_compute_global_forwarding_rule.app_fwd.ip_address
}
