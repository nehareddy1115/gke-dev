variable "project_id" {
    description = "The ID of the project in which to create the GKE cluster."
    type        = string
}

variable "region" {
    description = "The region in which to create the GKE cluster."
    type        = string
}

variable "subnet_cidr" {
    description = "The CIDR range for the subnet."
    type        = string
}

variable "pods_cidr" {
    description = "The CIDR range for the pods secondary IP range."
    type        = string
    default     = "10.1.0.0/24"
}

variable "services_cidr" {
    description = "The CIDR range for the services secondary IP range."
    type        = string
    default     = "10.2.0.0/24"
}

variable "enable_nat" {
    description = "Enable Cloud NAT for the router."
    type        = bool
    default     = true
}

variable "nat_ip_count" {
    description = "Number of NAT IPs to create."
    type        = number
    default     = 1
}

variable "nat_min_ports_per_vm" {
    description = "Minimum number of ports to allocate per VM for NAT."
    type        = number
    default     = 2048
}

variable "gke_cluster_name" {   
    description = "The name of the GKE cluster."
    type        = string
}

variable "master_ipv4_cidr_block" {
  description = "A /28 CIDR for the GKE control plane endpoint (private cluster requirement)."
  type        = string
  default     = "10.3.0.0/28"
}

variable "enable_private_endpoint" {
  description = "If true, kubernetes API is only reachable via private endpoint (best security)."
  type        = bool
  default     = true
}

variable "master_authorized_cidrs" {
  description = "Only used if enable_private_endpoint=false (public endpoint)."
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}

variable "enable_network_policy" {
  type    = bool
  default = true
}

variable "node_count" {
  type    = number
  default = 2
}

variable "machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "node_network_tags" {
  description = "Network tags applied to all nodes in this pool; used by firewall target_tags."
  type        = list(string)
  default     = ["internal"]
}

variable "node_labels" {
  type    = map(string)
  default = {}
}

variable "node_service_account_email" {
  description = "Optional: node SA email. You can use the default compute SA or create a dedicated one."
  type        = string
  default     = null
}

variable "credentials_file" {
  description = "The path to the GCP credentials file"
  type        = string
}
