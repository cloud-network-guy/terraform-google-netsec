locals {
  checkpoint = {
    machine_type          = "n2-standard-4" # Newer regions won't offer n1s
    labels                = {}
    disk_type             = "pd-ssd"
    disk_size             = 100
    disk_auto_delete      = true
    software_version      = "R81.20"
    license_type          = "BYOL"
    zones                 = ["b", "c"]
    cluster_address_names = ["primary-cluster-address", "secondary-cluster-address"]
    allow_upload_download = false
    enable_monitoring     = false
    admin_shell           = "/etc/cli.sh"
    cluster_description   = "CloudGuard Highly Available Security Cluster"
    template_version      = "20230117"
    smart_1_cloud_token   = ""
    image_versions = {
      "R81.20" = "631-991001245-v20230117"
      "R81.10" = "335-991001300-v20230509"
      "R81"    = "392-991001234-v20230117"
      "R80.40" = "294-991001234-v20230117"
    }
    image_prefix = "projects/checkpoint-public/global/images/check-point-"
  }
}

locals {
  _checkpoints = [for i, v in var.checkpoints :
    merge(v, {
      create                 = coalesce(v.create, true)
      project_id             = trimspace(coalesce(v.project_id, var.project_id))
      host_project_id        = trimspace(coalesce(v.host_project_id, var.host_project_id, v.project_id, var.project_id))
      install_type           = trimspace(coalesce(v.install_type, "Cluster"))
      license_type           = trimspace(lower(coalesce(v.license_type, "BYOL")))
      region                 = trimspace(v.region)
      software_version       = coalesce(v.software_version, local.checkpoint.software_version)
      allow_upload_download  = coalesce(v.allow_upload_download, local.checkpoint.allow_upload_download)
      enable_monitoring      = coalesce(v.enable_monitoring, local.checkpoint.enable_monitoring)
      admin_shell            = coalesce(v.admin_shell, local.checkpoint.admin_shell)
      service_account_scopes = coalesce(v.service_account_scopes, [])
    })
  ]
  __checkpoints = [for i, v in local._checkpoints :
    merge(v, {
      is_cluster         = v.install_type == "Cluster" ? true : false
      is_mig             = v.install_type == "AutoScale" ? true : false
      is_management      = length(regexall("Management", v.install_type)) > 0 ? true : false
      is_management_only = startswith(v.install_type, "Management") ? true : false
      is_manual          = startswith(v.install_type, "Manual") ? true : false
      software_code      = lower(replace(v.software_version, ".", ""))
      image_version      = lookup(local.checkpoint.image_versions, v.software_version, "error")
    })
  ]
  ___checkpoints = [for i, v in local.__checkpoints :
    merge(v, {
      is_gateway    = v.is_cluster || v.is_mig || length(regexall("Gateway", v.install_type)) > 0 ? true : false
      is_standalone = v.is_cluster || v.is_mig ? false : true
    })
  ]
  ____checkpoints = [for i, v in local.___checkpoints :
    merge(v, {
      image_type   = v.is_gateway ? "-gw" : ""
      install_code = v.is_manual || v.is_management_only ? "" : (v.is_standalone ? "single" : (v.is_mig ? "mig" : "cluster"))
    })
  ]
  _____checkpoints = [for i, v in local.____checkpoints :
    merge(v, {
      name                  = trimspace(lower(coalesce(v.name, substr("chkp-${v.install_code}-${v.region}", 0, 31))))
      description           = coalesce(v.description, v.is_cluster ? local.checkpoint.cluster_description : "Check Point Security Gateway")
      image                 = coalesce(v.image, "${local.checkpoint.image_prefix}${v.software_code}${v.image_type}-${v.license_type}-${v.install_code}-${v.image_version}")
      create_admin_password = v.admin_password == null ? true : false
      create_sic_key        = v.sic_key == null ? true : false
      startup_script_file   = v.is_management_only ? "cloud-config.sh" : "startup-script.sh"
      template_name         = v.is_cluster ? "${lower(v.install_type)}_tf" : "single_tf"
      template_version      = local.checkpoint.template_version
      smart_1_cloud_token   = local.checkpoint.smart_1_cloud_token
    }) if v.create == true
  ]
}

# If Admin password not provided, create random 16 character one
resource "random_string" "checkpoint_admin_password" {
  for_each = { for i, v in local._____checkpoints : v.name => true if v.create_admin_password == true }
  length   = 16
  special  = false
}

# If SIC key not provided, create random 8 character one
resource "random_string" "checkpoint_sic_key" {
  for_each = { for i, v in local._____checkpoints : v.name => true if v.create_sic_key == true }
  length   = 8
  special  = false
}

locals {
  checkpoints = [for i, v in local._____checkpoints :
    merge(v, {
      admin_password = v.create_admin_password ? random_string.checkpoint_admin_password[v.name].result : v.admin_password
      sic_key        = v.create_sic_key ? random_string.checkpoint_sic_key[v.name].result : v.sic_key
      #subnet_prefix     = "projects/${v.project_id}/regions/${v.region}/subnetworks"
      instance_suffixes              = v.is_cluster ? ["member-a", "member-b"] : ["gateway"]
      primary_cluster_address_name   = v.is_cluster ? "${v.name}-primary-cluster-address" : ""
      secondary_cluster_address_name = v.is_cluster ? "${v.name}-secondary-cluster-address" : ""
      index_key                      = "${v.project_id}/${v.name}"
    })
  ]
  # Create a list of objects for the instances so it's easier to iterate over
  _checkpoint_instances = flatten([for checkpoint in local.checkpoints :
    [for i, suffix in checkpoint.instance_suffixes :
      merge(checkpoint, {
        name = checkpoint.is_standalone ? checkpoint.name : "${checkpoint.name}-${suffix}"
        zone = checkpoint.zones != null ? "${checkpoint.region}-${checkpoint.zones[i]}" : "${checkpoint.region}-${local.checkpoint.zones[i]}"
      })
    ]
  ])
  checkpoint_instances = [for i, v in local._checkpoint_instances :
    merge(v, {
      machine_type     = coalesce(v.machine_type, local.checkpoint.machine_type)
      network_tags     = coalescelist(v.network_tags, v.is_gateway ? ["checkpoint-gateway"] : ["checkpoint-management"])
      labels           = coalesce(v.labels, local.checkpoint.labels)
      disk_type        = coalesce(v.disk_type, local.checkpoint.disk_type)
      disk_size        = coalesce(v.disk_size, local.checkpoint.disk_size)
      disk_auto_delete = coalesce(v.disk_auto_delete, local.checkpoint.disk_auto_delete)
      service_account_scopes = coalescelist(
        v.service_account_scopes,
        flatten(concat(
          ["https://www.googleapis.com/auth/monitoring.write"],
          v.is_cluster ? ["https://www.googleapis.com/auth/compute", "https://www.googleapis.com/auth/cloudruntimeconfig"] : [],
        ))
      )
      nics = [for n, nic in coalesce(v.nics, []) :
        {
          nic_index          = n
          instance_index_key = "${v.project_id}/${v.zone}/${v.name}"
          network            = nic.network
          subnetwork_project = v.host_project_id
          subnetwork         = nic.subnet
          project_id         = v.project_id
          region             = v.region
          create_external_ip = coalesce(
            nic.create_external_ip,
            v.is_cluster ? (n == 0 ? true : false) : null,
            false
          )
          external_ip_name = v.is_cluster ? (i == 0 ? v.primary_cluster_address_name : v.secondary_cluster_address_name) : null
        }
      ]
      index_key = "${v.project_id}/${v.zone}/${v.name}"
    }) if v.create == true
  ]
  checkpoint_nics = flatten([for i, v in local.checkpoint_instances : [for n, nic in v.nics : nic]])
}

locals {
  checkpoint_external_ips = [for i, v in local.checkpoint_nics :
    {
      project_id = v.project_id
      region     = v.region
      name       = v.external_ip_name
      index_key  = "${v.project_id}/${v.region}/${v.external_ip_name}"
    } if v.create_external_ip == true
  ]
}

# Create External Addresses
resource "google_compute_address" "external_ips" {
  for_each     = { for i, v in local.checkpoint_external_ips : v.index_key => v }
  project      = each.value.project_id
  name         = each.value.name
  region       = each.value.region
  address_type = "EXTERNAL"
}

# Get external IP status via data source (needed for clusters so IPs don't get reset after configuration)
data "google_compute_address" "external_ips" {
  for_each   = { for i, v in local.checkpoint_external_ips : v.index_key => v }
  project    = each.value.project_id
  name       = each.value.name
  region     = each.value.region
  depends_on = [google_compute_address.external_ips]
}

# Create Compute Engine Instances
resource "google_compute_instance" "default" {
  for_each                  = { for i, v in local.checkpoint_instances : v.index_key => v }
  project                   = each.value.project_id
  name                      = each.value.name
  description               = each.value.description
  zone                      = each.value.zone
  machine_type              = each.value.machine_type
  labels                    = each.value.labels
  tags                      = each.value.network_tags
  can_ip_forward            = each.value.is_gateway ? true : false
  allow_stopping_for_update = true
  resource_policies         = []
  boot_disk {
    auto_delete = false
    device_name = "${each.value.name}-boot"
    initialize_params {
      type  = each.value.disk_type
      size  = each.value.disk_size
      image = each.value.image
    }
  }
  dynamic "network_interface" {
    for_each = each.value.is_gateway ? each.value.nics : [each.value.nics[0]]
    content {
      network            = network_interface.value.network
      subnetwork_project = network_interface.value.subnetwork_project
      subnetwork         = network_interface.value.subnetwork
    }
  }
  service_account {
    email  = each.value.service_account_email
    scopes = each.value.service_account_scopes
  }
  metadata = {
    instanceSSHKey              = each.value.admin_ssh_key
    adminPasswordSourceMetadata = each.value.is_management_only ? null : each.value.admin_password
  }
  metadata_startup_script = each.value.is_manual ? null : templatefile("${path.module}/${each.value.startup_script_file}", {
    // script's arguments
    generatePassword               = each.value.is_management_only ? "false" : "true"
    config_url                     = "https://runtimeconfig.googleapis.com/v1beta1/projects/${each.value.project_id}/configs/${each.value.name}-config"
    config_path                    = "projects/${each.value.project_id}/configs/${each.value.name}-config"
    sicKey                         = each.value.sic_key
    allowUploadDownload            = each.value.allow_upload_download
    templateName                   = each.value.template_name
    templateVersion                = each.value.template_version
    templateType                   = "terraform"
    mgmtNIC                        = each.value.is_management ? "Private IP (eth0)" : "Private IP (eth1)"
    hasInternet                    = "true"
    enableMonitoring               = each.value.enable_monitoring
    shell                          = each.value.admin_shell
    installationType               = each.value.install_type
    installSecurityManagement      = each.value.is_management ? "true" : "false"
    computed_sic_key               = each.value.sic_key
    managementGUIClientNetwork     = coalesce(each.value.allowed_gui_clients, "0.0.0.0/0") # Controls access GAIA web interface
    primary_cluster_address_name   = each.value.primary_cluster_address_name
    secondary_cluster_address_name = each.value.secondary_cluster_address_name
    managementNetwork              = each.value.is_management ? "" : coalesce(each.value.sic_address, "192.0.2.132/32")
    numAdditionalNICs              = length(each.value.nics) - 2
    smart_1_cloud_token            = each.value.smart_1_cloud_token
    name                           = each.value.name
    zoneConfig                     = each.value.zone
    region                         = each.value.region

    /* TODO - Need to add these parameters to bash startup script
    domain_name = var.domain_name
    expert_password                = var.expert_password
    proxy_host = var.proxy_host
    proxy_port = coalesce(var.proxy_port, 8080)
    mgmt_routes = coalesce(var.mgmt_routes, "199.36.53.8/30")
    internal_routes =  coalesce(var.internal_routes, "10.0.0.0/8 172.16.0.0/12 192.168.0.0/16")
    */
  })
}

# Create Unmanaged Instance Group for each gateway, if desired
resource "google_compute_instance_group" "default" {
  for_each    = { for i, v in local.checkpoint_instances : v.index_key => v if v.create_instance_groups == true }
  project     = each.value.project_id
  name        = each.value.name
  description = "Unmanaged Instance Group for ${each.value.name}"
  network     = "projects/${each.value.host_project_id}/global/networks/${each.value.nics[0].network}"
  instances   = [google_compute_instance.default[each.value.index_key].self_link]
  zone        = each.value.zone
}
