
locals {
  _network_firewall_policies = [for i, v in local.firewall_policies :
    {
      create          = v.create
      project_id      = v.project_id
      host_project_id = v.project_id
      name            = v.name
      description     = v.description
      networks        = v.networks
      is_global       = v.region == null ? true : false
      region          = v.region
      rules           = v.rules
    } if v.type == "network"
  ]
  network_firewall_policies = [for i, v in local._network_firewall_policies :
    merge(v, {
      index_key = v.is_global ? "${v.project_id}/${v.name}" : "${v.project_id}/${v.region}/${v.name}"
    }) if v.create == true
  ]
}

# Global Network Firewall Policies
resource "google_compute_network_firewall_policy" "default" {
  for_each    = { for i, v in local.network_firewall_policies : v.index_key => v if v.is_global }
  project     = each.value.project_id
  name        = each.value.name
  description = each.value.description
}

# Regional Network Firewall Policies
resource "google_compute_region_network_firewall_policy" "default" {
  for_each    = { for i, v in local.network_firewall_policies : v.index_key => v if !v.is_global }
  project     = each.value.project_id
  name        = each.value.name
  description = each.value.description
  region      = each.value.region
}

# Locals for Rules
locals {
  _network_firewall_policy_rules = flatten([for i, v in local.network_firewall_policies :
    [for rule in v.rules :
      merge(rule, {
        rule_name = null
        is_global = v.is_global
        firewall_policy = coalesce(
          v.is_global ? try(google_compute_network_firewall_policy.default[v.index_key].name, null) : null,
          try(google_compute_region_network_firewall_policy.default[v.index_key].name, null),
        )
        index_key = v.is_global ? "${v.project_id}/${v.name}" : "${v.project_id}/${v.region}/${v.name}"
      })
    ]
  ])
  network_firewall_policy_rules = [for i, v in local._network_firewall_policy_rules :
    merge(v, {
      #index_key = v.is_global ? "${v.project_id}/${v.firewall_policy}/${v.priority}" : "${v.project_id}/${v.firewall_policy}/${v.name}"
      index_key = "${v.project_id}/${v.firewall_policy}/${v.priority}"
    }) if v.create == true
  ]
}

# Global Network Firewall Policy Rules
resource "google_compute_network_firewall_policy_rule" "default" {
  for_each                = { for i, v in local.network_firewall_policy_rules : v.index_key => v }
  project                 = each.value.project_id
  firewall_policy         = each.value.firewall_policy
  rule_name               = each.value.rule_name
  action                  = each.value.action
  priority                = each.value.priority
  description             = each.value.description
  direction               = each.value.direction
  disabled                = each.value.disabled
  enable_logging          = each.value.enable_logging
  target_service_accounts = each.value.target_service_accounts
  match {
    src_ip_ranges            = each.value.src_ip_ranges
    src_address_groups       = each.value.src_address_groups
    src_fqdns                = each.value.src_fqdns
    src_region_codes         = each.value.src_region_codes
    src_threat_intelligences = each.value.src_threat_intelligences
    dest_ip_ranges           = each.value.dest_ip_ranges
    dest_address_groups      = each.value.dest_address_groups
    dest_fqdns               = each.value.dest_fqdns
    dest_region_codes        = each.value.dest_region_codes
    dynamic "layer4_configs" {
      for_each = each.value.layer4_configs
      content {
        ip_protocol = layer4_configs.value.ip_protocol
        ports       = layer4_configs.value.ports
      }
    }
  }
  depends_on = [google_network_security_address_group.default]
}

/*

# Regional Network Firewall Policy Rules
resource "google_compute_region_network_firewall_policy_rule" "default" {
  for_each                = { for i, v in local.network_firewall_policy_rules : v.index_key => v if !v.is_global }
  project                 = each.value.project_id
  firewall_policy         = each.value.firewall_policy
  rule_name               = each.value.rule_name
  action                  = each.value.action
  priority                = each.value.priority
  description             = each.value.description
  direction               = each.value.direction
  disabled                = each.value.disabled
  enable_logging          = each.value.enable_logging
  target_service_accounts = each.value.target_service_accounts
  match {
    src_ip_ranges            = each.value.src_ip_ranges
    src_fqdns                = each.value.src_fqdns
    src_region_codes         = each.value.src_region_codes
    src_threat_intelligences = each.value.src_threat_intelligences
    dest_ip_ranges           = each.value.dest_ip_ranges
    dest_address_groups      = each.value.dest_address_groups
    dest_fqdns               = each.value.dest_fqdns
    dest_region_codes        = each.value.dest_region_codes
    layer4_configs {
      ip_protocol = "all"
    }
  }
  region     = each.value.region
  depends_on = [google_network_security_address_group.default]
}

*/

# Associations
locals {
  network_firewall_policy_associations = flatten(
    [for i, v in local.network_firewall_policies :
      [for network in v.networks :
        {
          project_id        = v.project_id
          name              = trimspace(lower(network)) #"projects/${v.host_project_id}/global/networks/${network}"
          index_key         = v.is_global ? "${v.host_project_id}/${network}" : null
          is_global         = v.is_global
          attachment_target = "${local.url_prefix}/${v.host_project_id}/global/networks/${network}"
          firewall_policy = coalesce(
            v.is_global ? try(google_compute_network_firewall_policy.default[v.index_key].name, null) : null,
            try(google_compute_region_network_firewall_policy.default[v.index_key].name, null)
          )
        } if v.create == true
      ]
    ]
  )
}

# Global Associations
resource "google_compute_network_firewall_policy_association" "default" {
  for_each          = { for i, v in local.network_firewall_policy_associations : v.index_key => v if v.is_global }
  project           = each.value.project_id
  name              = each.value.name
  attachment_target = each.value.attachment_target
  firewall_policy   = each.value.firewall_policy
  #depends_on        = [google_compute_network_firewall_policy.default]
}

# Regional Associations
resource "google_compute_region_network_firewall_policy_association" "default" {
  for_each          = { for i, v in local.network_firewall_policy_associations : v.index_key => v if !v.is_global }
  project           = each.value.project_id
  name              = each.value.name
  attachment_target = each.value.attachment_target
  firewall_policy   = each.value.firewall_policy
  region            = each.value.region
  #depends_on        = [google_compute_region_network_firewall_policy.default]
}
