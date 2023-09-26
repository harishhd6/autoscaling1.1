provider "aws" {
  region = "ap-south-1"  # Change this to your desired AWS region
}

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group for web servers"
  
  # Define your security group rules here, e.g., allow HTTP traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow SSH traffic (port 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = "harish-key"  # Replace with your desired key name
  public_key = file("/home/ec2-user/harish.pub")  # Replace with the path to your harish.pem public key file
}

# Create a Launch Template
resource "aws_launch_template" "example" {
  name_prefix          = "example-"
  image_id             = "ami-067c21fb1979f0b27"  # Replace with your desired AMI
  instance_type        = "t2.micro"               # Replace with your desired instance type
  key_name             = aws_key_pair.my_key_pair.key_name  # Use the key pair name defined above
  user_data            = base64encode(file("/home/ec2-user/user_data_script.sh"))  # Path to your new.sh file
  
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      delete_on_termination = true
      encrypted             = false
    }
  }
  network_interfaces {
    associate_public_ip_address = true
    security_groups            = [aws_security_group.web.id]
}
}

resource "aws_autoscaling_group" "example" {
  name_prefix         = "example-"
  launch_template {
    id = aws_launch_template.example.id
  }
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  vpc_zone_identifier = ["subnet-021a5cf968ce090d8"]  # Replace with your desired subnet ID(s)
}

resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  enable_deletion_protection = false
  
  enable_http2 = true

  subnets = ["subnet-021a5cf968ce090d8", "subnet-0a178d26da48c7543"]  # Replace with your desired subnet IDs
}

resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      
    }
  }
}

resource "aws_lb_target_group" "example" {
  name     = "example-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-05e9eb62c8ee28ff8"  # Replace with your VPC ID

  health_check {
    path                = "/clickops.html"
    port                = "80"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener_rule" "example" {
  listener_arn = aws_lb_listener.example.arn

  action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
     
    }
  }

  condition {
    path_pattern {
      values = ["/clickops.html"]
    }
  }
}

resource "aws_autoscaling_attachment" "example" {
  autoscaling_group_name = aws_autoscaling_group.example.name
  lb_target_group_arn   = aws_lb_target_group.example.arn
}

output "load_balancer_dns_name" {
  value = aws_lb.example.dns_name
}

output "instance_user_data" {
  value = aws_launch_template.example.user_data
}

