locals {
  # Each (rule, source) pair becomes its own rule resource. Keys use positions
  # rather than values so they stay known at plan time.
  ingress_rules = merge([
    for sg_key, sg in var.security_groups : merge([
      for ri, rule in sg.ingress_rules : merge(
        { for i, v in coalesce(rule.cidr_blocks, []) : "${sg_key}/in/${ri}/cidr/${i}" => merge(rule, { sg_key = sg_key, kind = "cidr", value = v }) },
        { for i, v in coalesce(rule.security_groups, []) : "${sg_key}/in/${ri}/sg/${i}" => merge(rule, { sg_key = sg_key, kind = "sg", value = v }) },
        { for i, v in coalesce(rule.source_security_group_keys, []) : "${sg_key}/in/${ri}/sgkey/${i}" => merge(rule, { sg_key = sg_key, kind = "sg_key", value = v }) },
        rule.self ? { "${sg_key}/in/${ri}/self" = merge(rule, { sg_key = sg_key, kind = "self", value = null }) } : {},
      )
    ]...)
  ]...)

  egress_rules = merge([
    for sg_key, sg in var.security_groups : merge([
      for ri, rule in sg.egress_rules : merge(
        { for i, v in coalesce(rule.cidr_blocks, []) : "${sg_key}/out/${ri}/cidr/${i}" => merge(rule, { sg_key = sg_key, kind = "cidr", value = v }) },
        { for i, v in coalesce(rule.security_groups, []) : "${sg_key}/out/${ri}/sg/${i}" => merge(rule, { sg_key = sg_key, kind = "sg", value = v }) },
        { for i, v in coalesce(rule.destination_security_group_keys, []) : "${sg_key}/out/${ri}/sgkey/${i}" => merge(rule, { sg_key = sg_key, kind = "sg_key", value = v }) },
      )
    ]...)
  ]...)
}
