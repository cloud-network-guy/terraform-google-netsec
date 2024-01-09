locals {
  _firewall_policies = [
    for i, v in var.firewall_policies :
    merge(v, {
      create     = coalesce(v.create, true)
      project_id = trimspace(lower(coalesce(v.project_id, var.project_id)))
      org_id     = try(coalesce(v.org_id, var.org_id), null)
      name       = trimspace(lower(coalesce(v.name, "firewall-policy-{$i}")))
      type       = lower(coalesce(v.type, "unknown"))
      networks   = coalesce(v.networks, [])
      rules = [
        for rule in coalesce(v.rules, []) :
        merge(rule, {
          create                    = coalesce(rule.create, true)
          project_id                = trimspace(lower(coalesce(v.project_id, var.project_id)))
          action                    = lower(coalesce(rule.action, "allow"))
          disabled                  = coalesce(rule.disabled, false)
          priority                  = coalesce(rule.priority, 1000)
          enable_logging            = coalesce(rule.logging, false)
          direction                 = upper(coalesce(rule.direction, rule.destination_ranges != null || rule.destination_address_groups != null ? "egress" : "ingress"))
          target_service_accounts   = coalesce(rule.target_service_accounts, [])
          src_ip_ranges             = rule.source_ranges
          src_address_groups        = coalesce(rule.source_address_groups, rule.address_groups, [])
          src_fqdns                 = [] # TODO
          src_region_codes          = [] # TODO
          src_threat_intelligences  = [] # TODO
          dest_ip_ranges            = rule.destination_ranges
          dest_address_groups       = coalesce(rule.destination_address_groups, rule.address_groups, [])
          dest_fqdns                = [] # TODO
          dest_region_codes         = [] # TODO
          dest_threat_intelligences = [] # TODO
          range_types               = toset(coalesce(rule.range_types, rule.range_type != null ? [rule.range_type] : []))
          protocols                 = coalesce(rule.protocols, rule.protocol != null ? [rule.protocol] : ["all"])
          ports                     = coalesce(rule.ports, rule.port != null ? [rule.port] : [])
        })
      ]
    })
  ]
}

# Get a list of unique range types in all rules
locals {
  firewall_rules = flatten([for i, v in local._firewall_policies : [for rule in v.rules : rule if rule.create == true]])
  range_types    = toset(flatten([for i, v in local.firewall_rules : [for rt in v.range_types : lower(rt)]]))
}
# Use data source to lookup current IP address blocks
data "google_netblock_ip_ranges" "default" {
  for_each   = local.range_types
  range_type = each.value
}

locals {
  firewall_policies = [for i, v in local._firewall_policies :
    merge(v, {
      rules = [for rule in v.rules :
        merge(rule, {
          range_types = [for range_type in rule.range_types : lower(range_type)]
          layer4_configs = [for protocol in rule.protocols :
            {
              ip_protocol = lower(protocol)
              ports       = try(coalescelist(rule.ports, contains(["tcp", "udp"], protocol) ? ["1-65535"] : []), null)
            }
          ]
          src_ip_ranges = rule.direction == "INGRESS" ? toset(coalesce(
            rule.src_ip_ranges,
            rule.ranges,
            flatten([for rt in rule.range_types : try(data.google_netblock_ip_ranges.default[lower(rt)].cidr_blocks, null)]),
            [],
          )) : null
          dest_ip_ranges = rule.direction == "EGRESS" ? toset(coalesce(
            rule.dest_ip_ranges,
            rule.ranges,
            flatten([for rt in rule.range_types : try(data.google_netblock_ip_ranges.default[lower(rt)].cidr_blocks, null)]),
            [],
          )) : null
          src_address_groups = rule.direction == "INGRESS" ? toset(flatten(
            [for address_group in rule.src_address_groups :
              try(google_network_security_address_group.default["${v.project_id}/${address_group}"].id, null)
            ]
          )) : null
          dest_address_groups = rule.direction == "EGRESS" ? toset(flatten(
            [for address_group in rule.dest_address_groups :
              try(google_network_security_address_group.default["${v.project_id}/${address_group}"].id, null)
            ]
          )) : null
        })
      ]
      type = v.type == "unknown" && length(v.networks) > 0 ? "network" : "unknown"
    }) if v.create == true
  ]
}



/*
locals {
  org_id             = "223280600632"
  policy_name        = "test1"
  policy_description = "Test Policy"
  #network_link = "projects/websites-270319/global/networks/test"
  network_link = "projects/otc-core-network-prod-4aea/global/networks/default"
}

resource "google_compute_firewall_policy" "default" {
  parent      = "organizations/${local.org_id}"
  short_name  = local.policy_name
  description = local.policy_description
}

resource "google_compute_firewall_policy_rule" "default" {
  firewall_policy = google_compute_firewall_policy.default.id
  priority        = 123
  direction       = "INGRESS"
  action          = "allow"
  match {
    dynamic "layer4_configs" {
      for_each = [{ protocol = "tcp", ports = ["1-65535"] }]
      content {
        ip_protocol = layer4_configs.value.protocol != null ? layer4_configs.value.protocol : "all"
        ports       = layer4_configs.value.ports
      }
    }
    src_ip_ranges = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
}
*/

/*
resource "google_folder" "default" {
  display_name = "Test Folder"
  parent       = "organizations/${local.org_id}"
}
*/

/*

resource "google_compute_firewall_policy_association" "default" {
  name              = "${local.policy_name}-association-1"
  firewall_policy   = google_compute_firewall_policy.default.id
  attachment_target = local.network_link #google_folder.default.name # x
}

*/
