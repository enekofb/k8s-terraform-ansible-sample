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


## Kubernetes Security

Security in Kubernetes is a important topic that has been recently improved from traditional Kubernetes setup. This section gives an overview on what are they for the given setup
explaining the more relevant details.  

### Kubernetes API Security

When a request to Kubernetes api is done, three main stage are walked through: [authentication, authorization and admission](https://kubernetes.io/docs/admin/accessing-the-api/).


#### [Authentication](https://kubernetes.io/docs/admin/authentication/)

Different [authentication](https://kubernetes.io/docs/admin/authentication/) methods are supported in Kubernetes. 
Kubernetes uses client certificates, bearer tokens, an authenticating proxy, or HTTP basic auth to authenticate API requests through authentication plugins.
Authentication brings about the user what is its Username, UID, Groups and metadata. 
The system:authenticated group is included in the list of groups for all authenticated users.

The cluster provisioned here setups in [api-server](./kubernetes/roles/master/templates/kube-apiserver.service.j2) 

1. [X509 Client Certs](https://kubernetes.io/docs/admin/authentication/#x509-client-certs) 

By using ` --client-ca-file=/var/lib/kubernetes/ca.pem` indicates that users that presents
certs signed by this CA will be authenticated. The common name of the subject is used as the user name for the request.

For instance,node01 presents a certificate based on the following configuration 

```
{
  "CN": "system:node:ip-10-0-20-30.eu-west-1.compute.internal",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "UK",
      "L": "London",
      "O": "system:nodes",
      "OU": "Cluster"
    }
  ]
}


```

Saying that its username is `"CN": "system:node:ip-10-0-20-30.eu-west-1.compute.internal"` and belong 
to the groups ` "O": "system:nodes"`.


2. [Service Account Tokens](https://kubernetes.io/docs/admin/authentication/#service-account-tokens)

Service accounts are usually created automatically by the API server and associated with pods running in the cluster through the ServiceAccount Admission Controller.
Bearer tokens are mounted into pods at well known locations, and allow in cluster processes to talk to the API server.

In our setup, it is specify using `  --service-account-key-file=/var/lib/kubernetes/ca-key.pem `.  

3. [Kubelet Authentication](https://kubernetes.io/docs/admin/kubelet-authentication-authorization/)

A kubelet’s HTTPS endpoint exposes APIs which give access to data of varying sensitivity, and allow you to perform operations with varying levels of power on the node and within containers. For 
that, api server needs to setup its way to authenticate against kubelet. Api server
uses certificates for its authentication.

```
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \
  --kubelet-https=true \

``` 

#### [Authorization](https://kubernetes.io/docs/admin/authorization/)

There are several authorization modes avaiable in kubernetes. Two are the modes
used in the current setup (Node and RBAC). Unlike authentication, authorization modes are well located as a setting in the api server by `authorization-mode` setting that in our case, 
as said is populated with `--authorization-mode=Node,RBAC`.

1. [Node](https://kubernetes.io/docs/admin/authorization/node/)

Node authorization is a special-purpose authorization mode that specifically authorizes API requests made by kubelets. Its use
happens when kubelets register itself against api-server. 
In order to be authorized by the Node authorizer, kubelets must use a credential that identifies them as being in the system:nodes group, with a username of system:node:<nodeName>. 
This group and user name format match the identity created for each kubelet as part of kubelet TLS bootstrapping.

```
{
  "CN": "system:node:ip-10-0-20-30.eu-west-1.compute.internal",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "UK",
      "L": "London",
      "O": "system:nodes",
      "OU": "Cluster"
    }
  ]
}
```

2. [RBAC](https://kubernetes.io/docs/admin/authorization/rbac/)

RBAC is used instead of ABAC. As of 1.8, RBAC mode is stable and backed by the rbac.authorization.k8s.io/v1 API. In addition to its usages for our applications, RBAC is used
for authorization in the context of system components. 

In particular, the following ClusterRoles and ClusterRoleBindings applies in the queries
that api-server does to any kubelet.

```
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
```      
that is binded to api-server (kubernetes user) by the following ClusterRoleBinding
      
```
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
```

#### [Admission Control](https://kubernetes.io/docs/admin/admission-controllers/)

The third level of security in the api server. Current setup defines the following list of 
admission controllers ` --admission-control=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota`


### Transport Security

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

### Install CFSSL (for Linux)

```
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
chmod +x cfssl_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
```

```
wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
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


### Runtime Security

### Network Security



### Infrastructure Security






### AWS KeyPair

- No longer needed so ssh into machine is done by using certs signed by CA.

### SSH using CA signed certs

In order to avoid to add to the servers the keys when added a new admin user to the cluster we could 
configure SSH server in any machine using CA cert signed approach. This feature is added to our setup
by using user data feature of our EC2 instances.

```

resource "aws_instance" "etcd" {
    ...
    user_data  = "${data.template_cloudinit_config.ssh_config.rendered}"

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
