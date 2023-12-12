variable "project_id" {
  type        = string
  description = "Default GCP Project ID (can be overridden at resource level)"
  default     = null
}
variable "host_project_id" {
  type        = string
  description = "Default GCP Project ID (can be overridden at resource level)"
  default     = null
}
variable "firewall_rules" {
  description = "List of Firewall Rules"
  type = list(object({
    create                  = optional(bool, true)
    project_id              = optional(string)
    name                    = optional(string)
    name_prefix             = optional(string)
    short_name              = optional(string)
    description             = optional(string)
    network                 = optional(string)
    network_name            = optional(string)
    priority                = optional(number)
    logging                 = optional(bool)
    direction               = optional(string)
    ranges                  = optional(list(string))
    range                   = optional(string)
    source_ranges           = optional(list(string))
    destination_ranges      = optional(list(string))
    range_types             = optional(list(string))
    range_type              = optional(string)
    protocol                = optional(string)
    protocols               = optional(list(string))
    port                    = optional(number)
    ports                   = optional(list(number))
    source_tags             = optional(list(string))
    source_service_accounts = optional(list(string))
    target_tags             = optional(list(string))
    target_service_accounts = optional(list(string))
    action                  = optional(string)
    allow = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })))
    deny = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })))
    enforcement = optional(bool)
    disabled    = optional(bool)
  }))
  default = []
}
variable "firewall_policies" {
  description = "List of Firewall Policies"
  type = list(object({
    create     = optional(bool, true)
    project_id = optional(string)
    name       = optional(string)
  }))
  default = []
}

variable "checkpoints" {
  description = "List of Checkpoint CloudGuards"
  type = list(object({
    create                 = optional(bool, true)
    project_id             = optional(string)
    host_project_id        = optional(string)
    name                   = string
    region                 = string
    zone                   = optional(string)
    description            = optional(string)
    install_type           = optional(string)
    instance_suffixes      = optional(string)
    zones                  = optional(list(string))
    machine_type           = optional(string)
    disk_type              = optional(string)
    disk_size              = optional(number)
    disk_auto_delete       = optional(bool)
    admin_password         = optional(string)
    expert_password        = optional(string)
    sic_key                = optional(string)
    allow_upload_download  = optional(bool)
    enable_monitoring      = optional(bool)
    license_type           = optional(string)
    image                  = optional(string)
    software_version       = optional(string)
    ssh_key                = optional(string)
    startup_script         = optional(string)
    admin_shell            = optional(string)
    admin_ssh_key          = optional(string)
    service_account_email  = optional(string)
    service_account_scopes = optional(list(string))
    labels                 = optional(map(string))
    network_tags           = optional(list(string))
    nics = list(object({
      network            = optional(string)
      subnet             = optional(string)
      create_external_ip = optional(bool)
    }))
    create_instance_groups = optional(bool)
    allowed_gui_clients    = optional(string)
    sic_address            = optional(string)
    auto_scale             = optional(bool)
    domain_name            = optional(string)
    mgmt_routes            = optional(list(string))
    internal_routes        = optional(list(string))
  }))
  default = []
}
