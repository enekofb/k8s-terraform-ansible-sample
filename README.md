# Kubernetes not the hardest way (or "Provisioning a Kubernetes Cluster on AWS using Terraform and Ansible")

A worked example to provision a Kubernetes cluster on AWS from scratch, using Terraform and Ansible. A scripted version of the famous tutorial [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way).

See the companion article https://opencredo.com/kubernetes-aws-terraform-ansible-1/ for details about goals, design decisions and simplifications.

Revisited with the following objectives

1. Revisit current tutorial to move from learning tool to a production-ready setup.
2. Upgrade to kuberentes 1.8.0.
3. Upgrade Terraform to 0.11.

## Infrastructure 

### AWS VPC

- Production-like VPC setup that including public and private subnettings.
- Cluster access through a Bastion instance that is accessible only by a Control IP.
- Public subnetting for Bastion instance and ELBs.
- Private subnetting for Kubernetes components. 
- Usage of NAT gateway for internal access to Internet.
- Security groups following minimum access required.
- Usage of EC2 instance IAM Roles to control instance usage to AWS services.
- SSH access to ec2 instances based on certs not keys.

### Kubernetes Components

- 3 EC2 instances for HA Kbernetes Master setup with: Kubernetes API, Scheduler and Controller Manager
- 3 EC2 instances for *etcd* cluster
- 3 EC2 instances as Kubernetes Workers (aka Minions or Nodes)
- Kubenet Pod networking (using CNI)
- HTTPS between components and control API using own CA.
- Node self-registrtion by using RBAC and NodeAuthorization.

## Tooling and versions usage

*Requirements on control machine:*

- Terraform v0.11
- Python (tested with Python 2.7.12, may be not compatible with older versions; requires Jinja2 2.8)
- Python *netaddr* module
- Ansible v2.4
- *cfssl* and *cfssljson*:  https://github.com/cloudflare/cfssl
- Kubectl - Kubernetes CLI
- SSH Agent
- (optionally) AWS CLI

*Components and version used for this tutorial:* 

- Kubernetes 1.8.0
- Docker 1.12.6
- etcd 3.2.8
- [CNI Based Networking](https://github.com/containernetworking/cni)
- Secure communication between all components (etcd, control plane, workers)
- Default Service Account and Secrets
- [RBAC authorization enabled](https://kubernetes.io/docs/admin/authorization)
- [TLS client certificate bootstrapping for kubelets](https://kubernetes.io/docs/admin/kubelet-tls-bootstrapping)
- DNS add-on


## Authentication/Authorization

### AWS KeyPair

- No longer needed so ssh into machine is done by using certs signed by CA.

### SSH using CA signed certs

In order to avoid to add to the servers the keys when added a new admin user to the cluster we could 
configure SSH server in any machine using CA cert signed approach. This feature is added to our setup
by using user data feature of our EC2 instances.

```

resource "aws_instance" "etcd" {
    ...
    user_data            = "${data.template_cloudinit_config.ssh_config.rendered}"

    tags {
}
```
where the script that cloud-init changes ssh configuration configuration to use `TrustedUserCAKeys`

```
#!/bin/bash

...

# Put the public key of our user CA in place.
cat << EOF > /etc/ssh/users_ca.pub
${users_ca_publickey}
EOF

# Ensure the centos user is the only user that can be accessed via certificate
cat << EOF > /etc/ssh/authorized_principals
ubuntu
EOF

# Line return is important!
cat << EOF >> /etc/ssh/sshd_config

TrustedUserCAKeys /etc/ssh/users_ca.pub
AuthorizedPrincipalsFile  /etc/ssh/authorized_principals
EOF

# Restart the ssh server
service sshd restart

```

### Terraform and Ansible authentication

Both Terraform and Ansible expect AWS credentials set in environment variables:
```
$ export AWS_ACCESS_KEY_ID=<access-key-id>
$ export AWS_SECRET_ACCESS_KEY="<secret-key>"
```

If you plan to use AWS CLI you have to set `AWS_DEFAULT_REGION`.

Ansible expects the SSH identity loaded by SSH agent:

```
$ ssh-add <keypair-name>.pem
```

## Defining the environment

Terraform expects some variables to define your working environment:

- `control_cidr`: The CIDR of your IP. Bastion instance will only accept connections from this address. Note this is a CIDR, not a single IP. e.g. `123.45.67.89/32` (mandatory)

**Note that Instances and Kubernetes API will be accessible only from the "control IP"**. If you fail to set it correctly, you will not be able to SSH into machines or run Ansible playbooks.

You may optionally redefine:

- `vpc_name`: VPC Name. Must be unique in the AWS Account (Default: "kubernetes")
- `elb_name`: ELB Name for Kubernetes API. Can only contain characters valid for DNS names. Must be unique in the AWS Account (Default: "kubernetes")
- `owner`: `Owner` tag added to all AWS resources. No functional use. It becomes useful to filter your resources on AWS console if you are sharing the same AWS account with others. (Default: "kubernetes")

The easiest way is creating a `terraform.tfvars` [variable file](https://www.terraform.io/docs/configuration/variables.html#variable-files) in `./terraform` directory. Terraform automatically imports it.

Sample `terraform.tfvars`:
```
control_cidr = "123.45.67.89/32"
vpc_name = "Lorenzo ETCD"
elb_name = "lorenzo-etcd"
owner = "Lorenzo"
```


### Changing AWS Region

By default, the project uses `eu-west-1`. To use a different AWS Region, set additional Terraform variables:

- `region`: AWS Region (default: "eu-west-1").
- `zone`: AWS Availability Zone (default: "eu-west-1a")
- `default_ami`: Pick the AMI for the new Region from https://cloud-images.ubuntu.com/locator/ec2/: Ubuntu 16.04 LTS (xenial), HVM:EBS-SSD

You also have to edit `./ansible/hosts/ec2.ini`, changing `regions = eu-west-1` to the new Region.

## Provision infrastructure, with Terraform

Run Terraform commands from `./terraform` subdirectory.

```
$ terraform plan
$ terraform apply
```

Terraform outputs public DNS name of Kubernetes API and Workers public IPs.
```
Apply complete! Resources: 12 added, 2 changed, 0 destroyed.
  ...
Outputs:

  kubernetes_api_dns_name = lorenzo-kubernetes-api-elb-1566716572.eu-west-1.elb.amazonaws.com
  kubernetes_workers_public_ip = 54.171.180.238,54.229.249.240,54.229.251.124
```

You will need them later (you may show them at any moment with `terraform output`).

### Generated SSH config

Terraform generates `ssh.cfg`, SSH configuration file in the project directory.
It is convenient for manually SSH into machines using node names (`controller0`...`controller2`, `etcd0`...`2`, `worker0`...`2`), but it is NOT used by Ansible.

e.g.
```
$ ssh -F ssh.cfg worker0
```

## Setting up a Certificate Authority and Creating TLS Certificates

[Extracted from] (https://github.com/enekofb/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md)

This lab requires the `cfssl` and `cfssljson` binaries. Download them from the [cfssl repository](https://pkg.cfssl.org).

- Added playbook in order to setup the certs


### Install CFSSL (for Mac Osx)

```
wget https://pkg.cfssl.org/R1.2/cfssl_darwin-amd64
chmod +x cfssl_darwin-amd64
sudo mv cfssl_darwin-amd64 /usr/local/bin/cfssl
```

```
wget https://pkg.cfssl.org/R1.2/cfssljson_darwin-amd64
chmod +x cfssljson_darwin-amd64
sudo mv cfssljson_darwin-amd64 /usr/local/bin/cfssljson
```

### Set up a Certificate Authority

- both CA configuration file and CA certificate signinig request could be found
at folder $k8s-terraform-ansible-sample/cert 


### Generate CA certificate and CA private key

```
cd $k8s-terraform-ansible-sample/cert
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

Results:

```
ca-key.pem
ca.pem
```


## Install Kubernetes, with Ansible

Run Ansible commands from `./ansible` subdirectory.

We have multiple playbooks.

### Generate CA and certs to use for provisioning kubernetes components

- located at `cert` folder.

```
$ ansible-playbook kubernetes-pki.yaml
```

### Install and set up Kubernetes cluster

Install Kubernetes components and *etcd* cluster.
```
$ ansible-playbook kubernetes.yaml
```

### Setup Kubernetes CLI

Configure Kubernetes CLI (`kubectl`) on your machine, setting Kubernetes API endpoint (as returned by Terraform).
```
$ ansible-playbook kubectl.yaml --extra-vars "kubernetes_api_endpoint=<kubernetes-api-dns-name>"
```

Verify all components and minions (workers) are up and running, using Kubernetes CLI (`kubectl`).

```
$ kubectl get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-2               Healthy   {"health": "true"}
etcd-1               Healthy   {"health": "true"}
etcd-0               Healthy   {"health": "true"}

 $ kubectl get nodes
NAME                                       STATUS    AGE
ip-10-43-0-30.eu-west-1.compute.internal   Ready     6m
ip-10-43-0-31.eu-west-1.compute.internal   Ready     6m
ip-10-43-0-32.eu-west-1.compute.internal   Ready     6m
```

### Setup Pod cluster routing

Set up additional routes for traffic between Pods.
```
$ ansible-playbook kubernetes-routing.yaml
```

### Smoke test: Deploy *nginx* service

Deploy a *ngnix* service inside Kubernetes.
```
$ ansible-playbook kubernetes-nginx.yaml
```

Verify pods and service are up and running.

```
$ kubectl get pods -o wide
NAME                     READY     STATUS    RESTARTS   AGE       IP           NODE
nginx-2032906785-9chju   1/1       Running   0          3m        10.200.1.2   ip-10-43-0-31.eu-west-1.compute.internal
nginx-2032906785-anu2z   1/1       Running   0          3m        10.200.2.3   ip-10-43-0-30.eu-west-1.compute.internal
nginx-2032906785-ynuhi   1/1       Running   0          3m        10.200.0.3   ip-10-43-0-32.eu-west-1.compute.internal

> kubectl get svc nginx --output=json
{
    "kind": "Service",
    "apiVersion": "v1",
    "metadata": {
        "name": "nginx",
        "namespace": "default",
...
```

Retrieve the port *nginx* has been exposed on:

```
$ kubectl get svc nginx --output=jsonpath='{range .spec.ports[0]}{.nodePort}'
32700
```

Now you should be able to access *nginx* default page:
```
$ curl http://<worker-0-public-ip>:<exposed-port>
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

The service is exposed on all Workers using the same port (see Workers public IPs in Terraform output).

# Known limitations / simplifications

There are still known simplifications which are listed below, compared to a production-ready solution:

- No actual integration between Kubernetes and AWS.
- No additional Kubernetes add-on (DNS, Dashboard, Logging...) -- TBA: is this still true?
- Simplified Ansible lifecycle. Playbooks support changes in a simplistic way, including possibly unnecessary restarts.
- Instances use static private IP addresses
- No stable private or public DNS naming (only dynamic DNS names, generated by AWS)
- Not using VPC Endpoint for services.
- EC2 IAM role need to restricted granted services access. 

# More 

needed to create this 

kubectl create clusterrolebinding system-authenticated-cluster-admin-binding-kubelet --clusterrole=cluster-admin --group=system:kubelet-bootstrap
clusterrolebinding "system-authenticated-cluster-admin-binding-kubelet" created
