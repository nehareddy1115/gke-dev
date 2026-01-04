locals {
  # We must create master_authorized_networks_config whenever private endpoint is enabled
  enable_master_authorized_networks = var.enable_private_endpoint || length(var.master_authorized_cidrs) > 0
}

# -------------------------
# Network
# -------------------------
resource "google_compute_network" "vpc_default" {
  name                    = "vpc-default"
  project                 = var.project_id
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "subnet_default" {
  name          = "subnet-default"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc_default.id
  ip_cidr_range = var.subnet_cidr

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  private_ip_google_access = true
}

resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  project = var.project_id
  network = google_compute_network.vpc_default.id

  allow {
    protocol = "all"
  }

  source_ranges = [var.subnet_cidr, var.pods_cidr, var.services_cidr]
  direction     = "INGRESS"
  priority      = 1000

  # Make sure your node pool tags include "gke-node"
  target_tags = ["gke-node"]
}

resource "google_compute_router" "router_default" {
  name    = "router-default"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc_default.id

  bgp {
    asn = 65001
  }
}

resource "google_compute_router_nat" "nat_default" {
  name                               = "nat-default"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.router_default.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.subnet_default.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  enable_endpoint_independent_mapping = true

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# -------------------------
# GKE Cluster
# -------------------------
resource "google_container_cluster" "gke_cluster" {
  name     = var.gke_cluster_name
  project  = var.project_id
  location = var.region

  # Use self_link to avoid name ambiguity
  network    = google_compute_network.vpc_default.self_link
  subnetwork = google_compute_subnetwork.subnet_default.self_link


  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  node_config {
    disk_size_gb = 30
    disk_type = "pd-balanced"
    machine_type = var.machine_type
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  dynamic "master_authorized_networks_config" {
    for_each = local.enable_master_authorized_networks ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_cidrs
        content {
          # NOTE: expects object keys "cidr" and "name" as you used earlier
          cidr_block   = cidr_blocks.value.cidr
          display_name = cidr_blocks.value.name
        }
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  network_policy {
    enabled  = var.enable_network_policy
    provider = "CALICO"
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  release_channel {
    channel = var.release_channel
  }
}

resource "google_container_node_pool" "default" {
  name     = "${var.gke_cluster_name}-np-default"
  project  = var.project_id
  location = var.region
  cluster  = google_container_cluster.gke_cluster.name
  max_pods_per_node = 32

  node_count = var.node_count

  lifecycle {
    create_before_destroy = false
  }

  node_config {
    disk_size_gb = 40
    disk_type = "pd-balanced"
    machine_type = var.machine_type

    # Make sure this includes "gke-node" if you want your firewall rule applied
    tags = var.node_network_tags

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels          = var.node_labels
    service_account = var.node_service_account_email
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}