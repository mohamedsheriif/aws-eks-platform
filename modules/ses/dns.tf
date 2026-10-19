# SES always issues exactly three DKIM tokens, so the keys are fixed indexes
# that are known at plan time even though the tokens are not.
resource "aws_route53_record" "dkim" {
  for_each = merge([
    for k, v in var.ses_identities : {
      for i in range(3) : "${k}/${i}" => { identity_key = k, index = i, zone_id = v.route53_zone_id }
    } if v.route53_zone_id != null
  ]...)

  zone_id = each.value.zone_id
  name    = "${aws_sesv2_email_identity.this[each.value.identity_key].dkim_signing_attributes[0].tokens[each.value.index]}._domainkey.${aws_sesv2_email_identity.this[each.value.identity_key].email_identity}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_sesv2_email_identity.this[each.value.identity_key].dkim_signing_attributes[0].tokens[each.value.index]}.dkim.amazonses.com"]
}
