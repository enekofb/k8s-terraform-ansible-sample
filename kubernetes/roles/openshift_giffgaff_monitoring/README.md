## Manual installation

1 - Create namespace

2 - Setup servicesaccount

```
oc adm policy add-scc-to-user hostaccess system:serviceaccount:monitoring:node-exporter
oc adm policy add-scc-to-user anyuid system:serviceaccount:monitoring:default
```

3 - Apply create the resources in the folder


Using helm

https://blog.openshift.com/getting-started-helm-openshift/

10591  oc login -u developer -p developer https://192.168.99.100:8443
10592  oc new-project tiller
10593* terraform apply
10594  ./helm init --client-only
10595  helm init --client-only
10596  oc process -f https://github.com/openshift/origin/raw/master/examples/helm/tiller-template.yaml -p TILLER_NAMESPACE="${TILLER_NAMESPACE}" | oc create -f -
10597  oc get pods -w