
locals {
  _address_groups = [for i, v in var.address_groups :
    merge(v, {
      create     = coalesce(v.create, true)
      project_id = coalesce(v.project_id, var.project_id)
      name       = trimspace(lower(coalesce(v.name, "address-group-${i}")))
      location   = trimspace(lower(v.region != null ? v.region : "global"))
      type       = "IPV4"
      capacity   = 100
      labels     = coalesce(v.labels, {})
      items      = v.items
      is_global  = v.region == null ? true : false
    })
  ]
  __address_groups = [for i, v in local._address_groups :
    merge(v, {
      parent   = "projects/${v.project_id}"
      location = v.is_global ? "global" : v.region
    })
  ]
  address_groups = [for i, v in local.__address_groups :
    merge(v, {
      index_key = v.is_global ? "${v.project_id}/${v.name}" : "${v.project_id}/${v.location}/${v.name}"
    }) if v.create == true
  ]
}
resource "google_network_security_address_group" "default" {
  for_each    = { for i, v in local.address_groups : v.index_key => v }
  name        = each.value.name
  description = each.value.description
  parent      = each.value.parent
  location    = each.value.location
  type        = each.value.type
  capacity    = each.value.capacity
  items       = each.value.items
  labels      = each.value.labels
}