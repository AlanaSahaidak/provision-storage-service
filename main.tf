resource "aws_vpc" "nebo_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "vpc_nebo"
  }
}

resource "aws_subnet" "nebo_public_subnet" {
  vpc_id                  = aws_vpc.nebo_vpc.id
  cidr_block              = var.subnet_public_cidr
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_nebo"
  }
}

resource "aws_subnet" "nebo_private_subnet" {
  vpc_id     = aws_vpc.nebo_vpc.id
  cidr_block = var.subnet_private_cidr
  tags = {
    Name = "private_subnet_nebo"
  }
}

resource "aws_internet_gateway" "nebo_igw" {
  vpc_id = aws_vpc.nebo_vpc.id
  tags = {
    Name = "igw-vnet-nebo"
  }
}

resource "aws_route_table" "nebo_route_table" {
  vpc_id = aws_vpc.nebo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nebo_igw.id
  }
}

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.nebo_public_subnet.id
  route_table_id = aws_route_table.nebo_route_table.id
}


resource "aws_instance" "bastion" {
  ami           = var.linux_ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.nebo_public_subnet.id
  key_name      = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "bastion"
  }
}

resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.nebo_vpc.id

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

  tags = {
    Name = "bastion_sg"
  }
}


resource "aws_key_pair" "main" {
  key_name   = "nebo_key"
  public_key = file("${var.ssh_key_path}.pub")
}

resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.nebo_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private_sg"
  }
}

resource "aws_instance" "linux" {
  ami           = var.linux_ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.nebo_private_subnet.id
  key_name      = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  tags = {
    Name = "vm-nebo-linux"
  }

}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
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

resource "aws_iam_policy" "s3_access_policy" {
  name = "s3_access_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_s3_bucket" "example" {
  bucket = "private-access-only-bucket"
  acl    = "private"

  tags = {
    Name        = "example-s3-bucket"
    Environment = "Private"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.s3"

  subnet_ids = [
    aws_subnet.private.id
  ]

  tags = {
    Name = "s3-endpoint"
  }
}