# ---------------------------------------------------------------------------
# Networking — VPC, public subnets, Internet Gateway, route table
#
# Architecture note (cost-conscious):
#   This configuration uses public subnets only and omits a NAT Gateway.
#   NAT Gateway costs ~$0.045/hour (~$32/month) plus data charges, which is
#   significant for a personal practice project.
#
#   Trade-off: In a later part, ECS Fargate tasks will run in these public
#   subnets with `assign_public_ip = true`. Security groups will restrict
#   inbound container traffic to the ALB security group only, so containers
#   are not directly reachable from the internet despite having public IPs.
#
#   For a hardened production environment, private subnets + NAT Gateway
#   (or VPC endpoints + Atlas PrivateLink) are strongly preferred because
#   containers would never have routable public IPs. This is documented as
#   future work.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# ---------------------------------------------------------------------------
# Public subnets — one per AZ
# ---------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false # Controlled per ECS service, not subnet-wide.

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  })
}

# ---------------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# ---------------------------------------------------------------------------
# Public route table
# ---------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Future work: private subnets
# ---------------------------------------------------------------------------
# For a hardened production setup, add:
#   - Private subnets (one per AZ, non-routable)
#   - NAT Gateway (or NAT instance) for outbound traffic from private subnets
#   - Separate private route table pointing 0.0.0.0/0 to NAT Gateway
#   - Move ECS tasks to private subnets (remove assign_public_ip = true)
#   - Consider Atlas PrivateLink for MongoDB Atlas connectivity
# These are omitted here to avoid NAT Gateway recurring charges on a
# personal practice project.
