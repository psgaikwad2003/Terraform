#Ec2 Instance

resource "aws_instance" "my_ec2" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  tags = {
    Name = "MyEC2Instance"
  }
}

#VPC
resource "aws_vpc" "my_vpc" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = "subnet-0bb1c79de3EXAMPLE"
  key_name      = "my-key"

  tags = {
    Name = "MyVPC"
  }
}

#subnet

resource "aws_subnet" "my_subnet"{
    vpc_id = aws_vpc.main.id
    cidr_block = "0.0.0.0/16 "
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

    tags = {
        Name = "MySubnet"
    }
}

#internet gateway

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MyInternetGateway"
  }
}

#route table

resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "MyRouteTable"
  }
}

#route table association

resoure "aws_route_association" "public"{
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.public.id

}

#security group

resource "aws_security_group" "my_sg" {
  name        = "my-security-group"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
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

    tags = {
        Name = "MySecurityGroup"
    }
}

#security group association

resource "aws_security_group_rule" "my_sg_rule" {
    security_group_id = aws_security_group.my_sg.id
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

#key pair

resource "aws_key_pair" "my_key_pair" {
    key_name = "my-key-pair"
    public_key = file("~/.ssh/id_rsa.pub")"
}

#IAM role

resources "aws_iam_role" "my_iam_role" {
    name = "my-iam-role"
    assume_role_policy = jsonencode({
        Version = "2025-7-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
            }
        ]
    })
}

#IAM User

resource "aws_iam_user" "my_iam_user" {
    name = "my-iam-user"
}

#IAM Policy

resource "aws_iam_policy" "my_iam_policy" {
    name = "my-iam-policy"
    policy = jsonencode({
        Version = "2025-7-17"
        Statement = [
            {
                Action = "ec2:*"
                Effect = "Allow"
                Resource = "*"
            }
        ]
    })
}

#s3 bucket

resource "aws_s3_bucket" "my_s3_bucket" {
    bucket = "my-s3-bucket"
    acl    = "private"

    tags = {
        Name = "MyS3Bucket"
    }
}

