variable control_cidr {
  description = "CIDR for maintenance: inbound traffic will be allowed from this IPs"
}

variable default_keypair_name {
  description = "Name of the KeyPair used for all nodes"
  default = "k8s-not-the-hardest-way"
}


variable vpc_name {
  description = "Name of the VPC"
  default = "kubernetes"
}

variable elb_name {
  description = "Name of the ELB for Kubernetes API"
  default = "kubernetes"
}

variable owner {
  default = "Kubernetes"
}

variable ansibleFilter {
  description = "`ansibleFilter` tag value added to all instances, to enable instance filtering in Ansible dynamic inventory"
  default = "Kubernetes" # IF YOU CHANGE THIS YOU HAVE TO CHANGE instance_filters = tag:ansibleFilter=Kubernetes01 in ./ansible/hosts/ec2.ini
}

# Networking setup
variable region {
  default = "eu-west-1"
}

variable zone {
  default = "eu-west-1a"
}

### VARIABLES BELOW MUST NOT BE CHANGED ###

variable vpc_cidr {
  default = "10.0.0.0/16"
}

variable subnet_public_cidr {
  default = "10.0.10.0/24"
}

variable subnet_private_cidr {
  default = "10.0.20.0/24"
}


variable kubernetes_pod_cidr {
  default = "10.200.0.0/16"
}


variable route53_zone_id {
  default = "10.200.0.0/16"
}

# Instances Setup
variable amis {
  description = "Default AMIs to use for nodes depending on the region"
  type = "map"
  default = {
    ap-northeast-1 = "ami-0567c164"
    ap-southeast-1 = "ami-a1288ec2"
    cn-north-1 = "ami-d9f226b4"
    eu-central-1 = "ami-8504fdea"
    eu-west-1 = "ami-0d77397e"
    sa-east-1 = "ami-e93da085"
    us-east-1 = "ami-40d28157"
    us-west-1 = "ami-6e165d0e"
    us-west-2 = "ami-a9d276c9"
  }
}
variable default_instance_user {
  default = "ubuntu"
}

variable etcd_instance_type {
  default = "t2.micro"
}
variable master_instance_type {
  default = "t2.micro"
}
variable worker_instance_type {
  default = "t2.micro"
}

variable "bastion_instance_type" {
  default = "t2.micro"
}

variable kubernetes_cluster_dns {
  default = "10.31.0.1"
}

variable "this_repo" {
  default = "git@github.com:enekofb/k8s-terraform-ansible-sample.git"
}

variable "instance_profile_id" {
  default = "kubernetes"
}

variable "users_ca_publickey" {}

