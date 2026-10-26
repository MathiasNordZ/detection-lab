variable "external_network_name" {
  description = "Existing OpenStack network used as the router gateway."
  type        = string
}

variable "image_name" {
  description = "Ubuntu cloud image name available in this OpenStack project."
  type        = string
}

variable "flavor_soc" {
  type        = string
  description = "Flavor with at least 8 vCPU and 16 GiB RAM recommended."
  default     = ""
}

variable "flavor_attacker" {
  type        = string
  description = "Flavor for the Caldera/Atomic operator node."
  default     = ""
}

variable "flavor_target" {
  type        = string
  description = "Flavor for the monitored Linux endpoint."
  default     = ""
}

variable "keypair_name" {
  type        = string
  description = "Existing OpenStack SSH keypair name."
}

variable "trusted_cidr" {
  type        = string
  description = "Administrator public IP in CIDR form; restrict ingress to this address."
  validation {
    condition     = can(cidrhost(var.trusted_cidr, 0)) && var.trusted_cidr != "0.0.0.0/0"
    error_message = "Set a valid, narrow CIDR. 0.0.0.0/0 is not allowed."
  }
}

variable "region" {
  type        = string
  description = "Optional OpenStack region override."
  default     = null
  nullable    = true
}

variable "lab_name" {
  type        = string
  default     = "detection-lab"
}

variable "lab_cidr" {
  type        = string
  default     = "10.77.0.0/24"
}

variable "soc_disk_gb" {
  type        = number
  default     = 100
}

variable "ssh_username" {
  type        = string
  default     = "ubuntu"
}
