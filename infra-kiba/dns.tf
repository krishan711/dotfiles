resource "aws_route53_zone" "evrpg" {
  name = "evrpg.com"
}

resource "aws_route53_zone" "kibadev" {
  name = "kiba.dev"
}

resource "aws_acm_certificate" "evrpg" {
  domain_name = aws_route53_zone.evrpg.name
  subject_alternative_names = ["*.${aws_route53_zone.evrpg.name}"]
  validation_method = "DNS"
  provider = aws.virginia

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "kibadev" {
  domain_name = aws_route53_zone.kibadev.name
  subject_alternative_names = [
    "*.${aws_route53_zone.kibadev.name}",
    aws_route53_zone.evrpg.name,
    "*.${aws_route53_zone.evrpg.name}",
  ]
  validation_method = "DNS"
  provider = aws.virginia

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "evrpg_acm" {
  zone_id = aws_route53_zone.evrpg.zone_id
  name = tolist(aws_acm_certificate.evrpg.domain_validation_options)[0].resource_record_name
  records = [tolist(aws_acm_certificate.evrpg.domain_validation_options)[0].resource_record_value]
  type = tolist(aws_acm_certificate.evrpg.domain_validation_options)[0].resource_record_type
  ttl = 60
}

resource "aws_route53_record" "kibadev_acm" {
  zone_id = aws_route53_zone.kibadev.zone_id
  for_each = {
    for dvo in aws_acm_certificate.kibadev.domain_validation_options : dvo.domain_name => {
      name = dvo.resource_record_name
      record = dvo.resource_record_value
      type = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name = each.value.name
  records = [each.value.record]
  ttl = 60
  type = each.value.type
}

resource "aws_route53_record" "kibadev_evrpg_acm" {
  zone_id = aws_route53_zone.evrpg.zone_id
  for_each = {
    for dvo in aws_acm_certificate.kibadev.domain_validation_options : dvo.domain_name => {
      name = dvo.resource_record_name
      record = dvo.resource_record_value
      type = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name = each.value.name
  records = [each.value.record]
  ttl = 60
  type = each.value.type
}

locals {
  appbox_ip = "52.211.242.27"
  vpnbox_ip = "34.249.191.66"
}

resource "aws_route53_record" "kibadev_all" {
  zone_id = aws_route53_zone.kibadev.zone_id
  type = "A"
  name = "*"
  records = [local.appbox_ip]
  ttl = 5
}

# resource "aws_route53_record" "kibadev_vpn" {
#   zone_id = aws_route53_zone.kibadev.zone_id
#   type = "A"
#   name = "vpn"
#   records = ["34.251.244.59"]
#   ttl = 5
# }

resource "aws_route53_record" "kibadev_vpn2" {
  zone_id = aws_route53_zone.kibadev.zone_id
  type = "A"
  name = "vpn2"
  records = [local.vpnbox_ip]
  ttl = 600
}
