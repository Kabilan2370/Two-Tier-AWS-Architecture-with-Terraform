resource "aws_vpc" "one" {
  cidr_block       = var.cidr_block
  instance_tenancy = "default"
  enable_dns_hostnames = var.host_name

  tags = {
    Name = "SAM-vpc"
  }
}
# public subnet 1
resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.one.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1e"

  tags = {
    Name = "pub-sub-one"
  }
}

# public subnet 2
resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.one.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1f"

  tags = {
    Name = "pub-sub-two"
  }
}
# private subnet 1
resource "aws_subnet" "sub3" {
  vpc_id                 = aws_vpc.one.id
  cidr_block             = "10.0.3.0/24"
  availability_zone      = "us-east-1g"
  map_public_ip_on_launch = false

  tags = {
    Name = "pri-sub-one"
  }
}
# private subnet 2
resource "aws_subnet" "sub4" {
  vpc_id                 = aws_vpc.one.id
  cidr_block             = "10.0.4.0/24"
  availability_zone      = "us-east-1h"
  map_public_ip_on_launch = false

  tags = {
    Name = "pri-sub-two"
  }
}

# IG
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.one.id

  tags = {
    Name = "Gateway"
  }
}

# Route table
resource "aws_route_table" "route1" {
  vpc_id                  = aws_vpc.one.id

  route {
    cidr_block            = "0.0.0.0/0"
    gateway_id            = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "route-table-one"
  }
}
# Association 
resource "aws_route_table_association" "a" {
  subnet_id                = aws_subnet.sub1.id
  route_table_id           = aws_route_table.route1.id
}
# public route table 2
resource "aws_route_table" "route2" {
  vpc_id = aws_vpc.one.id

  route {
    cidr_block              = "0.0.0.0/0"
    gateway_id              = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "route-table-two"
  }
}
# database subnet 
resource "aws_db_subnet_group" "sub_4_db" {
  name       = "db-table"
  subnet_ids = [aws_subnet.sub3.id, aws_subnet.sub4.id]
  tags = {
    Name = "DB-subnet"
  }
}
# Association 
resource "aws_route_table_association" "b" {
  subnet_id                 = aws_subnet.sub2.id
  route_table_id            = aws_route_table.route2.id
}
# Elastic IP
resource "aws_eip" "ip" {
  #instance                  = aws_instance..id
  domain                    = "vpc"
}

# NAT gatway
resource "aws_nat_gateway" "nat" {
  allocation_id             = aws_eip.ip.id
  subnet_id                 = aws_subnet.sub2.id

  tags = {
    Name = "Nat-gate"
  }

  depends_on = [aws_internet_gateway.gw]
}

# private Route table 1
resource "aws_route_table" "route3" {
  vpc_id                    = aws_vpc.one.id

  route {
    cidr_block              = "0.0.0.0/0"
    gateway_id              = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "pri-route-one"
  }
}
resource "aws_route_table_association" "c" {
  subnet_id                 = aws_subnet.sub3.id
  route_table_id            = aws_route_table.route3.id
}

# private route table 2
resource "aws_route_table" "route4" {
  vpc_id = aws_vpc.one.id

  route {
    cidr_block              = "0.0.0.0/0"
    gateway_id              = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "pri-route-two"
  }
}
resource "aws_route_table_association" "d" {
  subnet_id                 = aws_subnet.sub4.id
  route_table_id            = aws_route_table.route4.id
}


# security group
resource "aws_security_group" "public_sg" {
  name                      = "public-sg"
  description               = "Allow web and ssh traffic"
  vpc_id                    = aws_vpc.one.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_instance" "master" {
  ami                           = var.ami_id
  instance_type                 = var.inst_type
  subnet_id                     = aws_subnet.sub1.id
  key_name                      = var.key
  associate_public_ip_address   = var.public_key
  security_groups               = [aws_security_group.public_sg.id]
  user_data                   = <<-EOF
                              #!/bin/bash
                              apt update -y
                              apt install httpd -y
                              systemctl start httpd
                              systemctl enable httpd
                              echo "<html><body><h1> Machine 1 </h1></body></html>" > /var/www/html/index.html
        
                              EOF
  tags = {
    name = "Master"
}

}

resource "aws_instance" "slave" {
  ami                           = var.ami_id
  instance_type                 = var.inst_type
  subnet_id                     = aws_subnet.sub2.id
  key_name                      = var.key
  associate_public_ip_address   = var.public_key
  security_groups               = [aws_security_group.public_sg.id]
  user_data                   = <<-EOF
                              #!/bin/bash
                              apt update -y
                              apt install httpd -y
                              systemctl start httpd
                              systemctl enable httpd
                              echo "<html><body><h1> Machine 1 </h1></body></html>" > /var/www/html/index.html
                              EOF
  tags = {
    name = "slaves1"
}
}

# Application load balancer
resource "aws_lb" "mani" {
  name                       = "Application"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.public_sg.id]
  subnets                    = [aws_subnet.sub1.id,aws_subnet.sub2.id]
  
  tags = {
    Environment = "Rams"
  }
}
# target group
resource "aws_lb_target_group" "test" {
  name                      = "padayappa"
  port                      = 80
  protocol                  = "HTTP"
  target_type               = "instance"
  vpc_id                    = aws_vpc.one.id

  depends_on = [aws_vpc.one]
}

resource "aws_lb_target_group_attachment" "testrt" {
  target_group_arn           = aws_lb_target_group.test.arn
  target_id                  = aws_instance.master.id
  port                       = 80

  depends_on = [aws_instance.master]
}
resource "aws_lb_target_group_attachment" "testrt2" {
  target_group_arn           = aws_lb_target_group.test.arn
  target_id                  = aws_instance.slave.id
  port                       = 80

  depends_on = [aws_instance.slave]
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn           = aws_lb.mani.arn
  port                        = "80"
  protocol                    = "HTTP"
  
  default_action {
    type                      = "forward"
    target_group_arn          = aws_lb_target_group.test.arn
  }
}

# db security group     
resource "aws_security_group" "private-db" {
  name                      = "private-db"
  description               = "Allow web and ssh traffic"
  vpc_id                    = aws_vpc.one.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
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

# database instance
resource "aws_db_instance" "the_db" {
  allocated_storage      = 10
  engine                 = "MySQL"
  engine_version         = "5.7"
  instance_class         = "t2.micro"
  db_subnet_group_name   = aws_db_subnet_group.sub_4_db.id
  vpc_security_group_ids = [aws_security_group.private-db.id]
  #name                   = "database"
  username               = "username"
  password               = "password"
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot    = true
}

