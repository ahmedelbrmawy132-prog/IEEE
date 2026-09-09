terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. Custom VPC
resource "aws_vpc" "campfire_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "campfire-vpc"
  }
}

# 2. Subnets (Public for ALB/ECS & Private for RDS Isolation)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.campfire_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "campfire-public-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.campfire_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = { Name = "campfire-public-2" }
}

resource "aws_subnet" "private_db_1" {
  vpc_id            = aws_vpc.campfire_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "${var.aws_region}a"
  tags = { Name = "campfire-private-db-1" }
}

resource "aws_subnet" "private_db_2" {
  vpc_id            = aws_vpc.campfire_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}b"
  tags = { Name = "campfire-private-db-2" }
}

# 3. Internet Gateway & Routing for Public Subnets
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.campfire_vpc.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.campfire_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "pub_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "pub_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# 4. Security Groups (Strict DB Isolation)
resource "aws_security_group" "app_sg" {
  name        = "campfire-app-sg"
  description = "Allows incoming traffic to app services"
  vpc_id      = aws_vpc.campfire_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name        = "campfire-db-sg"
  description = "Strict DB access only from application subnet"
  vpc_id      = aws_vpc.campfire_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. RDS Subnet Group (Private Isolated)
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "campfire-rds-subnet-group"
  subnet_ids = [aws_subnet.private_db_1.id, aws_subnet.private_db_2.id]
}

# 6. Task 2: Amazon RDS PostgreSQL 16 (Single-AZ for Cost Optimization)
resource "aws_db_instance" "postgres" {
  identifier             = "campfire-postgres-prod"
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  max_allocated_storage  = 50
  storage_type           = "gp3"
  multi_az               = false # Cost optimization approved

  db_name  = "campfire_db"
  username = "campfire_admin"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  backup_retention_period = 1 # Automated daily backups enabled
  skip_final_snapshot     = true
  publicly_accessible     = false
}

# 7. Task 1: ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "campfire-ecs-cluster"
}

# 8. Task 7: FinOps Budget Watchdog ($100 Limit)
resource "aws_budgets_budget" "cost_watchdog" {
  name              = "campfire-100-usd-limit"
  budget_type       = "COST"
  limit_amount      = "100"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}
# ============================================================================
# Task 5: Amazon Elastic Container Registry (ECR)
# ============================================================================
resource "aws_ecr_repository" "go_gateway" {
  name                 = "campfire-go-gateway"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "python_ml" {
  name                 = "campfire-python-ml"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ============================================================================
# Task 3: AWS Application Load Balancer (ALB) & Routing Gates
# ============================================================================
resource "aws_lb" "campfire_alb" {
  name               = "campfire-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  # 3600s Idle Timeout to prevent emergency WebSocket drops
  idle_timeout = 3600

  tags = {
    Name = "campfire-public-alb"
  }
}

# Target Group for Go Gateway (HTTP REST)
resource "aws_lb_target_group" "tg_gateway_http" {
  name        = "tg-go-gateway-http"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.campfire_vpc.id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# Target Group for Emergency WebSockets (/ws/sos) with Stickiness & 3600s Keep-Alive
resource "aws_lb_target_group" "tg_gateway_ws" {
  name        = "tg-go-gateway-ws"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.campfire_vpc.id
  target_type = "ip"

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 10
  }
}

# ALB HTTP Listener (Port 80)
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.campfire_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_gateway_http.arn
  }
}

# Dedicated Routing Rule for SOS WebSockets: /ws/sos*
resource "aws_lb_listener_rule" "ws_sos_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_gateway_ws.arn
  }

  condition {
    path_pattern {
      values = ["/ws/sos*"]
    }
  }
}