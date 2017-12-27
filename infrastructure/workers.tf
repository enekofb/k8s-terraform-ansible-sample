
############################################
# K8s Worker (aka Nodes, Minions) Instances
############################################

resource "aws_instance" "worker" {
    count = 1
    ami = "${lookup(var.amis, var.region)}"
    instance_type = "${var.worker_instance_type}"

    subnet_id = "${aws_subnet.private.id}"
    private_ip = "${cidrhost(var.subnet_private_cidr, 30 + count.index)}"
    associate_public_ip_address = false
    availability_zone = "${var.zone}"
    vpc_security_group_ids = ["${aws_security_group.worker-sg.id}"]

    iam_instance_profile = "${var.instance_profile_id}"
    user_data            = "${data.template_cloudinit_config.ssh_config.rendered}"

    tags {
      Owner = "${var.owner}"
      Name = "worker-${count.index}"
      ansibleFilter = "${var.ansibleFilter}"
      ansibleNodeType = "worker"
      ansibleNodeName = "worker${count.index}"
    }

    lifecycle {
      ignore_changes = ["user_data"]
    }

}

output "kubernetes_workers_public_ip" {
  value = "${join(",", aws_instance.worker.*.public_ip)}"
}

resource "aws_security_group" "worker-sg" {
  vpc_id = "${aws_vpc.kubernetes.id}"
  name = "worker-sg"

  # Allow inbound traffic to the port used by Kubernetes API HTTPS
  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  # Allow inbound traffic to the port used by Kubernetes API HTTPS
  ingress {
    from_port = 443
    to_port = 443
    protocol = "TCP"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "TCP"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    from_port = 10250
    to_port = 10250
    protocol = "tcp"
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

  egress {
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }


  tags {
    Owner = "${var.owner}"
    Name = "worker-sg"
  }
}
