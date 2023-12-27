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
variable "org_id" {
  type        = number
  description = "Default Org ID Number (can be overridden at resource level)"
  default     = null
}
variable "address_groups" {
  type = list(object({
    create      = optional(bool, true)
    project_id  = optional(string)
    org_id      = optional(number)
    name        = optional(string)
    description = optional(string)
    parent      = optional(string)
    region      = optional(string)
    type        = optional(string)
    capacity    = optional(number)
    items       = list(string)
    labels      = optional(map(string))
  }))
  default = []
}
variable "firewall_policies" {
  description = "List of Policies"
  type = list(object({
    create      = optional(bool, true)
    project_id  = optional(string)
    org_id      = optional(number)
    name        = optional(string)
    description = optional(string)
    type        = optional(string)
    networks    = optional(list(string))
    region      = optional(string)
    rules = optional(list(object({
      create                     = optional(bool, true)
      priority                   = optional(number)
      description                = optional(string)
      direction                  = optional(string)
      ranges                     = optional(list(string))
      range                      = optional(string)
      source_ranges              = optional(list(string))
      destination_ranges         = optional(list(string))
      address_groups             = optional(list(string))
      range_types                = optional(list(string))
      range_type                 = optional(string)
      protocol                   = optional(string)
      protocols                  = optional(list(string))
      port                       = optional(number)
      ports                      = optional(list(number))
      source_address_groups      = optional(list(string))
      destination_address_groups = optional(list(string))
      target_tags                = optional(list(string))
      target_service_accounts    = optional(list(string))
      action                     = optional(string)
      logging                    = optional(bool)
      disabled                   = optional(bool)
    })))
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
