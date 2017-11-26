#########################
# etcd cluster instances
#########################

resource "aws_instance" "etcd" {
    count = 1
    ami = "${lookup(var.amis, var.region)}"
    instance_type = "${var.etcd_instance_type}"

    subnet_id = "${aws_subnet.private.id}"
    private_ip = "${cidrhost(var.subnet_private_cidr, 10 + count.index)}"
    associate_public_ip_address = false
    availability_zone = "${var.zone}"
    vpc_security_group_ids = ["${aws_security_group.etcd-sg.id}"]
    key_name = "${var.default_keypair_name}"

    iam_instance_profile = "${var.instance_profile_id}"
    user_data            = "${module.etcd_bootstrap.cloud_init_config}"

    tags {
      Owner = "${var.owner}"
      Name = "etcd-${count.index}"
      ansibleFilter = "${var.ansibleFilter}"
      ansibleNodeType = "etcd"
      ansibleNodeName = "etcd${count.index}"
    }


//    lifecycle {
//      ignore_changes = ["user_data"]
//    }

}

module "etcd_bootstrap" {
  source              = "/Users/eneko/projects/enekofb/terraform-module-bootstrap/ssh_bootstrap"

  ssh_ca_publickey      = "${var.ssh_ca_publickey}"
  github_ssh_privatekey = "${var.github_ssh_privatekey}"
}


resource "aws_security_group" "etcd-sg" {
  vpc_id = "${aws_vpc.kubernetes.id}"
  name = "etcd-sg"

  # Allow inbound traffic to the port used by Kubernetes API HTTPS
  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["${var.control_cidr}"]
  }


  # Allow inbound traffic to the port used by Kubernetes API HTTPS
  ingress {
    from_port = 2379
    to_port = 2379
    protocol = "TCP"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

//  ingress {
//    from_port = 2379
//    to_port = 2379
//    protocol = "TCP"
//    self = true
//  }

  ingress {
    from_port = 2380
    to_port = 2380
    protocol = "TCP"
    self = true
  }


  egress {
    from_port = 2380
    to_port = 2380
    protocol = "TCP"
    self = true
  }

  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Owner = "${var.owner}"
    Name = "etcd-sg"
  }
}

