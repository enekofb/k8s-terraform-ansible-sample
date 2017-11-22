############
## VPC
############

resource "aws_vpc" "kubernetes" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = true

  tags {
    Name = "${var.vpc_name}"
    Owner = "${var.owner}"
  }
}

# DHCP Options are not actually required, being identical to the Default Option Set
resource "aws_vpc_dhcp_options" "dns_resolver" {
  domain_name = "${var.region}.compute.internal"
  domain_name_servers = ["AmazonProvidedDNS"]

  tags {
    Name = "${var.vpc_name}"
    Owner = "${var.owner}"
  }
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id ="${aws_vpc.kubernetes.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.dns_resolver.id}"
}

##########
# Keypair
##########

resource "aws_key_pair" "default_keypair" {
  key_name = "${var.default_keypair_name}"
  public_key = "${var.default_keypair_public_key}"
}


############
## Subnets
############

# Subnet (public)
resource "aws_subnet" "public" {
  vpc_id = "${aws_vpc.kubernetes.id}"
  cidr_block = "${var.subnet_public_cidr}"
  availability_zone = "${var.zone}"

  tags {
    Name = "kubernetes"
    Owner = "${var.owner}"
  }
}

# Subnet (private)
resource "aws_subnet" "private" {
  vpc_id     = "${aws_vpc.kubernetes.id}"
  cidr_block = "${var.subnet_private_cidr}"
  availability_zone = "${var.zone}"

  tags {
    Name = "kubernetes"
    Owner = "${var.owner}"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.kubernetes.id}"
  tags {
    Name = "Internet Gateway"
    Owner = "${var.owner}"
  }
}

resource "aws_eip" "ngw-eip" {
  vpc      = true

}


resource "aws_nat_gateway" "ngw" {
  allocation_id = "${aws_eip.ngw-eip.id}"
  subnet_id     = "${aws_subnet.private.id}"

  tags {
    Name = "Nat Gateway"
    Owner = "${var.owner}"
  }

}

############
## Routing
############

resource "aws_route_table" "public" {
    vpc_id = "${aws_vpc.kubernetes.id}"

    # Default route through Internet Gateway
    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.igw.id}"
    }

    tags {
      Name = "kubernetes"
      Owner = "${var.owner}"
    }
}

resource "aws_route_table_association" "public" {
  subnet_id = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}


resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.kubernetes.id}"

  # Default route through Nat Gateway
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.ngw.id}"
  }

  tags {
    Name = "kubernetes"
    Owner = "${var.owner}"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.private.id}"
}


###########
## Bastion
###########

resource "aws_instance" "bastion" {
  count = 1
  ami = "${lookup(var.amis, var.region)}"
  instance_type = "${var.bastion_instance_type}"

  subnet_id = "${aws_subnet.public.id}"
  private_ip = "${cidrhost(var.subnet_public_cidr, 40 + count.index)}"


  availability_zone = "${var.zone}"
  vpc_security_group_ids = ["${aws_security_group.bastion-sg.id}"]
  key_name = "${var.default_keypair_name}"

  tags {
    Owner = "${var.owner}"
    Name = "bastion"
    ansibleFilter = "${var.ansibleFilter}"
    ansibleNodeType = "worker"
    ansibleNodeName = "worker${count.index}"
  }
}

resource "aws_eip" "bastion-eip" {
  vpc      = true

}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = "${aws_instance.bastion.id}"
  allocation_id = "${aws_eip.bastion-eip.id}"
}

resource "aws_security_group" "bastion-sg" {
  vpc_id = "${aws_vpc.kubernetes.id}"
  name = "bastion-sg"

  # Allow inbound traffic to the port used by Kubernetes API HTTPS
  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["${var.control_cidr}"]
  }

  # Allow inbound traffic to the port used by Kubernetes API HTTPS
  egress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  tags {
    Owner = "${var.owner}"
    Name = "bastion-sg"
  }
}
