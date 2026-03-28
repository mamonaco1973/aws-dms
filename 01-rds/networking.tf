# ===============================================================================
# VPC CONFIGURATION FOR RDS INFRASTRUCTURE
# ===============================================================================
# Defines the networking foundation required for RDS and Aurora resources,
# including the VPC, public subnets, routing, and internet connectivity.
# ===============================================================================

resource "aws_vpc" "rds-vpc" {

  # IPv4 CIDR block for the VPC
  cidr_block = "10.0.0.0/24"

  # Enable internal DNS resolution
  enable_dns_support = true

  # Enable DNS hostnames for EC2 instances
  enable_dns_hostnames = true

  tags = {
    Name          = "rds-vpc"
    ResourceGroup = "rds-asg-rg"
  }
}

# ===============================================================================
# INTERNET GATEWAY
# ===============================================================================
# Provides outbound internet access for resources within the VPC.
# ===============================================================================

resource "aws_internet_gateway" "rds-igw" {

  # Attach the internet gateway to the VPC
  vpc_id = aws_vpc.rds-vpc.id

  tags = {
    Name = "rds-igw"
  }
}

# ===============================================================================
# PUBLIC ROUTE TABLE
# ===============================================================================
# Routes outbound traffic from public subnets to the internet gateway.
# ===============================================================================

resource "aws_route_table" "public" {

  # Associate route table with the VPC
  vpc_id = aws_vpc.rds-vpc.id

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route" "default_route" {

  # Target route table
  route_table_id = aws_route_table.public.id

  # Catch-all IPv4 route
  destination_cidr_block = "0.0.0.0/0"

  # Forward traffic to the internet gateway
  gateway_id = aws_internet_gateway.rds-igw.id
}

# ===============================================================================
# PUBLIC SUBNETS
# ===============================================================================
# Defines public subnets across multiple availability zones.
# ===============================================================================

resource "aws_subnet" "rds-subnet-1" {

  # Parent VPC
  vpc_id = aws_vpc.rds-vpc.id

  # CIDR block for subnet
  cidr_block = "10.0.0.0/26"

  # Assign public IPs on launch
  map_public_ip_on_launch = true

  # Availability zone placement
  availability_zone = "us-east-2a"

  tags = {
    Name = "rds-subnet-1"
  }
}

resource "aws_subnet" "rds-subnet-2" {

  # Parent VPC
  vpc_id = aws_vpc.rds-vpc.id

  # CIDR block for subnet
  cidr_block = "10.0.0.64/26"

  # Assign public IPs on launch
  map_public_ip_on_launch = true

  # Availability zone placement
  availability_zone = "us-east-2b"

  tags = {
    Name = "rds-subnet-2"
  }
}

# ===============================================================================
# ROUTE TABLE ASSOCIATIONS
# ===============================================================================
# Associates public subnets with the public route table.
# ===============================================================================

resource "aws_route_table_association" "public_rta_1" {

  # Subnet association
  subnet_id = aws_subnet.rds-subnet-1.id

  # Route table assignment
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_rta_2" {

  # Subnet association
  subnet_id = aws_subnet.rds-subnet-2.id

  # Route table assignment
  route_table_id = aws_route_table.public.id
}
