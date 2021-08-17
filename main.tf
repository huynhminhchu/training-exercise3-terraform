provider "aws" {
  region = "us-east-1"
}
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "MyVPC"
  }
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myvpc.id

}
# 3. Create Custom Route Table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}
# 4. Create 2 public subnet 
resource "aws_subnet" "public_us_east_1a" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}
resource "aws_subnet" "public_us_east_1b" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}
# 5. Create 2 route table association : public-subnet +++ route table
resource "aws_route_table_association" "myvpc_us_east_1a_public" {
  subnet_id = aws_subnet.public_us_east_1a.id 
  route_table_id = aws_route_table.prod-route-table.id
}
resource "aws_route_table_association" "myvpc_us_east_1b_public" {
  subnet_id = aws_subnet.public_us_east_1b.id 
  route_table_id = aws_route_table.prod-route-table.id
}

#6. Create SG for web server 
resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow HTTP,HTTPS inbound connections"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["103.199.6.128/25","103.199.7.0/24","42.114.17.70/32"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["103.199.6.128/25","103.199.7.0/24","42.114.17.70/32"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    #-1 = all 
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP,HTTPS Security Group"
  }
}
#7 Create Launch config for auto scaling group 
resource "aws_launch_configuration" "web" {
  name = "web-"
  image_id = "ami-09e67e426f25ce0d7" 
  instance_type = "t2.micro"
  security_groups = [aws_security_group.allow_web.id]
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y 
              sudo apt-get install nginx -y
              sudo systemctl start nginx
              EOF
  #Launch Configurations cannot be updated after creation with the Amazon Web Service API
  lifecycle { 
    create_before_destroy = true
  }  
}
#8 Declare auto scaling group 
resource "aws_autoscaling_group" "web" {
  name = "web-asg"
  min_size = 1
  desired_capacity = 1 
  max_size = 1
  health_check_type = "EC2"
  launch_configuration = aws_launch_configuration.web.name
  vpc_zone_identifier = [
    aws_subnet.public_us_east_1a.id,
    aws_subnet.public_us_east_1b.id
  ]
  lifecycle {
    create_before_destroy = true
  }
}

