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
          create                   = coalesce(rule.create, true)
          project_id               = trimspace(lower(coalesce(v.project_id, var.project_id)))
          action                   = lower(coalesce(rule.action, "allow"))
          disabled                 = coalesce(rule.disabled, false)
          priority                 = coalesce(rule.priority, 1000)
          enable_logging           = coalesce(rule.logging, false)
          direction                = upper(coalesce(rule.direction, "ingress"))
          target_service_accounts  = coalesce(rule.target_service_accounts, [])
          src_ip_ranges            = rule.source_ranges
          src_fqdns                = [] # TODO
          src_region_codes         = [] # TODO
          src_threat_intelligences = [] # TODO
          range_types              = toset(coalesce(rule.range_types, rule.range_type != null ? [rule.range_type] : []))
          protocols                = coalesce(v.protocols, v.protocol != null ? [v.protocol] : ["all"])
        })
      ]
    })
  ]
}
locals {
  firewall_rules = flatten([for i, v in local._firewall_policies : v.rules])
  range_types    = toset(flatten([for i, v in local.firewall_rules : v.range_types]))
}
data "google_netblock_ip_ranges" "default" {
  for_each   = local.range_types
  range_type = each.value
}

locals {
  firewall_policies = [for i, v in local._firewall_policies :
    merge(v, {
      rules = [for rule in v.rules :
        merge(rule, {
          layer4_configs = [for protocol in rule.protocols :
            {
              protocol = lower(protocol)
              ports    = coalesce(v.ports, "1-65535")
            }
          ]
          src_ip_ranges = rule.direction == "INGRESS" ? toset(coalesce(
            rule.source_ranges,
            rule.ranges,
            flatten([for rt in rule.range_types : try(data.google_netblock_ip_ranges.default[rt].cidr_blocks, null)]),
            [],
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