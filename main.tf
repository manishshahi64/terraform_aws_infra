resource "aws_vpc" "myvpc" {
    cidr_block = var.vpc_cidr
}

resource "aws_subnet" "subnet1" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet2" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "my_igw" {
    vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "my_route_table" {
    vpc_id = aws_vpc.myvpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_igw.id
    }
}

resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.subnet1.id
    route_table_id = aws_route_table.my_route_table.id
}

resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.subnet2.id
    route_table_id = aws_route_table.my_route_table.id
}

resource "aws_security_group" "mysg" {
    name = "web"
    vpc_id = aws_vpc.myvpc.id

    ingress {
        description = "HTTP from VPC"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SSH from VPC"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1" # all protocols
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
      Name = "mysg"
    }
}

resource "aws_instance" "webserver1" {
    ami = "ami-0261755bbcb8c4a84"
    instance_type = var.instances_type
    vpc_security_group_ids = [ aws_security_group.mysg.id ]
    subnet_id = aws_subnet.subnet1.id
    user_data = base64encode(file("userdata1.sh"))
}

resource "aws_instance" "webserver2" {
    ami = "ami-0261755bbcb8c4a84"
    instance_type = var.instances_type
    vpc_security_group_ids = [ aws_security_group.mysg.id ]
    subnet_id = aws_subnet.subnet2.id
    user_data = base64encode(file("userdata2.sh"))
}

resource "aws_alb" "myalb" {
    name = "myalb"
    internal = false    # load balancer internet-facing, with public IP
    load_balancer_type = "application"
    security_groups = [ aws_security_group.mysg.id ]
    subnets = [ aws_subnet.subnet1.id, aws_subnet.subnet2.id ]
    tags = {
      Name = "web"
    }
}

resource "aws_lb_target_group" "tg" {
    name = "mytg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.myvpc.id
    health_check {
      path = "/"
      port = "traffic-port" # Health check should use the same port that the target group is using for traffic.
    }
}

resource "aws_lb_target_group_attachment" "mytgattach1" {
    target_group_arn = aws_lb_target_group.tg.arn
    target_id = aws_instance.webserver1.id
    port = 80
}

resource "aws_lb_target_group_attachment" "mytgattach2" {
    target_group_arn = aws_lb_target_group.tg.arn
    target_id = aws_instance.webserver2.id
    port = 80
}

resource "aws_lb_listener" "mylblisteners" {
    load_balancer_arn = aws_alb.myalb.arn
    port = 80
    protocol = "HTTP"
    default_action {
      target_group_arn = aws_lb_target_group.tg.arn
      type = "forward"
    }
}
