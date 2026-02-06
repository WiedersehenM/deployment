resource "aws_security_group" "alb_sg" {
  count = var.create_alb_sg && var.existing_alb_arn == "" ? 1 : 0

  name        = "${var.name}-sg"
  description = "Allow HTTP and HTTPS inbound to ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Application Load Balancer
resource "aws_lb" "this" {
  count = var.existing_alb_arn == "" ? 1 : 0

  name                       = var.name
  internal                   = var.internal
  load_balancer_type         = "application"
  security_groups            = concat([aws_security_group.alb_sg[0].id], var.security_group_ids)
  subnets                    = var.subnet_ids
  enable_deletion_protection = false
  tags                       = var.tags
}


locals {
  alb_arn = var.existing_alb_arn != "" ? var.existing_alb_arn : aws_lb.this[0].arn
}

locals {
  https_listener_arn = var.existing_https_listener_arn != "" ? var.existing_https_listener_arn : aws_lb_listener.https[0].arn
}


# Target Group
resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name        = "${each.value.name}-tg20260205"
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = each.value.health_check_path
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = merge(
    var.tags,
    { "Name" = each.value.name }
  )
}


# HTTPS Listener
resource "aws_lb_listener" "https" {
  count = var.existing_https_listener_arn == "" ? 1 : 0

  load_balancer_arn = local.alb_arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  certificate_arn = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = values(aws_lb_target_group.this)[0].arn
  }
}

// 已有 HTTPS Listener：追加证书
resource "aws_lb_listener_certificate" "additional" {
  count = var.existing_https_listener_arn != "" ? 1 : 0

  listener_arn    = var.existing_https_listener_arn
  certificate_arn = var.acm_certificate_arn
}
