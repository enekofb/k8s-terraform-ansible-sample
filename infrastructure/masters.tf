############################
# K8s Master instances
############################

resource "aws_instance" "master" {

    count = 1
    ami = "${lookup(var.amis, var.region)}"
    instance_type = "${var.master_instance_type}"

    subnet_id = "${aws_subnet.private.id}"
    private_ip = "${cidrhost(var.subnet_private_cidr, 20 + count.index)}"
    associate_public_ip_address = false # Instances have public, dynamic IP

    availability_zone = "${var.zone}"
    vpc_security_group_ids = ["${aws_security_group.master-sg.id}"]

    iam_instance_profile = "${var.instance_profile_id}"
    user_data            = "${data.template_cloudinit_config.ssh_config.rendered}"

    tags {
        Owner = "${var.owner}"
        Name = "master-${count.index}"
        ansibleFilter = "${var.ansibleFilter}"
        ansibleNodeType = "master"
        ansibleNodeName = "master${count.index}"
        "kubernetes.io/cluster/khw" = "khw"
    }

    lifecycle {
      ignore_changes = ["user_data"]
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
      "kubernetes.io/cluster/khw" = "khw"

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


  tags {
    Owner = "${var.owner}"
    Name = "master-elb-sg"
    "kubernetes.io/cluster/khw" = "khw"
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

  egress {
    from_port = 2379
    to_port = 2379
    protocol = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

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

  egress {
    from_port = 10250
    to_port = 10250
    protocol = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  //TODO add rest of the ports

  tags {
    Owner = "${var.owner}"
    Name = "master-sg"
    "kubernetes.io/cluster/khw" = "khw"
  }
}
