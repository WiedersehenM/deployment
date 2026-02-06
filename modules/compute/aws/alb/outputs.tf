output "alb_arn" {
  value = var.existing_alb_arn != null ? var.existing_alb_arn : aws_lb.this[0].arn
}

output "alb_dns_name" {
  value = var.existing_alb_arn != null ? null : aws_lb.this[0].dns_name
}

output "target_group_arns" {
  value = { for k, tg in aws_lb_target_group.this : k => tg.arn }
}

output "https_listener_arn" {
  value = var.existing_https_listener_arn != null ? var.existing_https_listener_arn : aws_lb_listener.https[0].arn
}
