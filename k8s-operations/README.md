
# Kubernetes operations playbooks

This is a non curated set of playbooks intended to use for some of the most common operations of kubernetes. 

## Kubernetes operations setup

In order to setup your cluster with the tooling needed for running operation tasks, runs `ansible-playbook -v k8s-operations.yaml`

It will install:
- pip
- pip modules to use aws services in ansible 
- awscli

## Kubernetes backup

Requirements:

- Snapshots are stored into S3 so the ETCD host that snapshot is taken from needs to be properly setup for interact with S3 (ec2 instance profiles recommended).


### Kubernetes create snapshot

- In order to create a snapshot for a given kubernetes cluster `ansible-playbook -v k8s-backup.yaml --tags create`

### Kubernetes restore snapshot

- In order to restore a snapshot use the following `ansible-playbook -v k8s-backup.yaml --tags restore`


