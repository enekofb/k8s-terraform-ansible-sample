############################
# K8s Master instances
############################

resource "aws_instance" "master" {

    count = 3
    ami = "${lookup(var.amis, var.region)}"
    instance_type = "${var.master_instance_type}"

    iam_instance_profile = "${aws_iam_instance_profile.kubernetes.id}"

    subnet_id = "${aws_subnet.private.id}"
    private_ip = "${cidrhost(var.subnet_private_cidr, 20 + count.index)}"
    associate_public_ip_address = false # Instances have public, dynamic IP

    availability_zone = "${var.zone}"
    vpc_security_group_ids = ["${aws_security_group.master-sg.id}"]
    key_name = "${var.default_keypair_name}"

    tags {
      Owner = "${var.owner}"
      Name = "master-${count.index}"
      ansibleFilter = "${var.ansibleFilter}"
      ansibleNodeType = "master"
      ansibleNodeName = "master${count.index}"
    }
}

###############################
## Kubernetes API Load Balancer
###############################

resource "aws_elb" "master-elb" {
    name = "${var.elb_name}"
    instances = ["${aws_instance.master.*.id}"]
    subnets = ["${aws_subnet.public.id}"]
    cross_zone_load_balancing = false

    security_groups = ["${aws_security_group.master-elb-sg.id}"]

    listener {
      lb_port = 6443
      instance_port = 6443
      lb_protocol = "TCP"
      instance_protocol = "TCP"
    }

    health_check {
      healthy_threshold = 2
      unhealthy_threshold = 2
      timeout = 15
      target = "HTTP:8080/healthz"
      interval = 30
    }

    tags {
      Name = "master-elb"
      Owner = "${var.owner}"
    }
}

resource "aws_security_group" "master-elb-sg" {

  vpc_id = "${aws_vpc.kubernetes.id}"
  name = "master-elb-sg"

  # Allow inbound traffic to the port used by Kubernetes API HTTPS
  ingress {
    from_port = 6443
    to_port = 6443
    protocol = "TCP"
    cidr_blocks = ["${var.control_cidr}"]
  }

  egress {
    from_port = 6443
    to_port = 6443
    protocol = "TCP"
    cidr_blocks = ["${var.subnet_private_cidr}"]
  }

}


############
## Security
############

resource "aws_security_group" "master-sg" {
  vpc_id = "${aws_vpc.kubernetes.id}"
  name = "master-sg"

  # Allow inbound traffic to the port used by Kubernetes API HTTPS
  ingress {
    from_port = 6443
    to_port = 6443
    protocol = "TCP"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  # Allow inbound traffic to the port used by Kubernetes API HTTPS
  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  # Allow all outbound traffic
  egress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  //TODO add rest of the ports

  tags {
    Owner = "${var.owner}"
    Name = "master-sg"
  }
}
