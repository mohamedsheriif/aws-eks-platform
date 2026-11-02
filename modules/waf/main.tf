resource "aws_wafv2_web_acl" "this" {
  for_each = var.web_acls

  name  = each.value.name
  scope = each.value.scope

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = { for i, group in each.value.managed_rule_groups : group => i }
    content {
      name     = rule.key
      priority = rule.value

      # Use the rule group's own actions.
      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = each.value.rate_limit == null ? [] : [each.value.rate_limit]
    content {
      name     = "rate-limit"
      priority = length(each.value.managed_rule_groups)

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = rule.value
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "rate-limit"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = each.value.name
    sampled_requests_enabled   = true
  }

  tags = merge({
    Name = format("%s-%s-%s-waf", var.project, var.env, each.key)
  }, var.tags)
}
