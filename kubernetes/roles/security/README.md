# Kubernetes security role

## Features

0. Required that PSP admission controller has been enabled.
1. Create a Pod Security Policy with security constraints.
2. Allows `default` Service Account in `default` Namespace to use the previous PSP by creating according Role and RoleBinding.
3. No other users has access to previous PSP so 

## Running root containers are not allowed
 

```
root@ip-10-0-20-30:/home/ubuntu# kubectl create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      pause
spec:
  containers:
    - name:  pause
      image: gcr.io/google-containers/pause
EOF
pod "pause" created
root@ip-10-0-20-30:/home/ubuntu# kubectl  get pods
NAME      READY     STATUS                       RESTARTS   AGE
pause     0/1       CreateContainerConfigError   0          6s
root@ip-10-0-20-30:/home/ubuntu# kubectl  describe pods
Name:         pause
Namespace:    default
Node:         ip-10-0-20-30.eu-west-1.compute.internal/10.0.20.30
Start Time:   Wed, 27 Dec 2017 10:54:24 +0000
Labels:       <none>
Annotations:  container.apparmor.security.beta.kubernetes.io/pause=runtime/default
              kubernetes.io/psp=restricted
              seccomp.security.alpha.kubernetes.io/pod=docker/default
Status:       Pending
IP:           10.200.0.5
Containers:
  pause:
    Container ID:
    Image:          gcr.io/google-containers/pause
    Image ID:
    Port:           <none>
    State:          Waiting
      Reason:       CreateContainerConfigError
    Ready:          False
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-hgjsp (ro)
Conditions:
  Type           Status
  Initialized    True
  Ready          False
  PodScheduled   True
Volumes:
  default-token-hgjsp:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-hgjsp
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     <none>
Events:
  Type     Reason                 Age               From                                               Message
  ----     ------                 ----              ----                                               -------
  Normal   Scheduled              13s               default-scheduler                                  Successfully assigned pause to ip-10-0-20-30.eu-west-1.compute.internal
  Normal   SuccessfulMountVolume  10s               kubelet, ip-10-0-20-30.eu-west-1.compute.internal  MountVolume.SetUp succeeded for volume "default-token-hgjsp"
  Normal   Pulling                8s (x2 over 10s)  kubelet, ip-10-0-20-30.eu-west-1.compute.internal  pulling image "gcr.io/google-containers/pause"
  Normal   Pulled                 7s (x2 over 9s)   kubelet, ip-10-0-20-30.eu-west-1.compute.internal  Successfully pulled image "gcr.io/google-containers/pause"
  Warning  Failed                 7s (x2 over 9s)   kubelet, ip-10-0-20-30.eu-west-1.compute.internal  Error: container has runAsNonRoot and image will run as root
  Warning  FailedSync             7s (x2 over 9s)   kubelet, ip-10-0-20-30.eu-west-1.compute.internal  Error syncing pod
root@ip-10-0-20-30:/home/ubuntu#
```

## Running non root containers is allowed

Using the following [nginx container](https://hub.docker.com/r/tomaskral/nonroot-nginx/~/dockerfile/)

`kubectl  run nginx-nonroot --image=tomaskral/nonroot-nginx`

```
kubectl  get pods
NAME                             READY     STATUS                       RESTARTS   AGE
nginx-nonroot-7656c69c69-ll6fq   1/1       Running                      0          28s
```