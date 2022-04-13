# Installation

The installation of `Strimzi Operator` and `CRDs` can be done in multiple ways using kubernetes `manifests`, `Kustomize`, `Helm`, etc..

## Helm

[Strimzi Operator Helm Chart](https://github.com/strimzi/strimzi-kafka-operator/tree/main/helm-charts/helm3/strimzi-kafka-operator) is going to be used to customize the installation.

```bash
# Install strimzi operator using helm
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Install operator using specific version

# NOTES: 
#  * By default 'watchAnyNamespace' is set to false, so it needs 'watchNamespaces' to be set.
#  * Namespaces within 'watchNamespaces' parameter must exist previously (i.e kafka)
#  * Use '--skip-crds' flag to not get an error re-installing the chart installing the crds.
#  * Using `helm template` throws some errors. It is recommended ti use `helm install` cli instead.

kubectl create ns kafka
helm install strimzi strimzi/strimzi-kafka-operator -n strimzi --create-namespace --version 0.28.0 --wait \
    --set watchNamespaces='{kafka}'

# Wait until the operator is installed
```

Uninstall Strimzi

```bash
# Delete strimzi operator
helm delete strimzi -n strimzi 
```

## Kafka Cluster

### Kafka Persistent

Kafka clusters should be created using `persistent` storage.

```bash
# Apply the `Kafka` Cluster CR file (single)
kubectl apply -f examples/kafka/kafka-persistent-single.yaml -n kafka 

# Apply the `Kafka` Cluster CR file (HA)
kubectl apply -f examples/kafka/kafka-persistent.yaml -n kafka 

# Wait while Kubernetes starts the required pods, services and so on:
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n kafka 

# Get all the pods created by the cluster HA
kubectl get pods -n kafka

# NAMESPACE     NAME                                          READY   STATUS      RESTARTS      AGE
# kafka         my-cluster-zookeeper-0                        1/1     Running     0             4m24s
# kafka         my-cluster-zookeeper-2                        1/1     Running     0             4m24s
# kafka         my-cluster-zookeeper-1                        1/1     Running     0             4m24s
# kafka         my-cluster-kafka-0                            1/1     Running     0             3m57s
# kafka         my-cluster-kafka-2                            1/1     Running     0             3m57s
# kafka         my-cluster-kafka-1                            1/1     Running     0             3m57s
# kafka         my-cluster-entity-operator-67cbb8f86f-qfl8z   2/3     Running     1 (66s ago)   3m17s
```

It can be created **multiples** volumes to be used by kafka brokers to increase the `I/O`.

```bash
# Apply the `Kafka` Cluster CR file (HA)
kubectl apply -f examples/kafka/kafka-jbod.yaml -n kafka 

# Wait while Kubernetes starts the required pods, services and so on:
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n kafka 

# Get all the pvs created by the cluster
kubectl get pvc -n kafka --sort-by=.metadata.name

# NAME                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# data-0-my-cluster-kafka-0     Bound    pvc-2569fefc-3abc-457f-a63c-9ddbd70e247a   100Gi      RWO            local-path     5m39s
# data-0-my-cluster-kafka-1     Bound    pvc-2fa70c51-01b3-470f-84a9-7ba8b6e3519b   100Gi      RWO            local-path     3m24s
# data-0-my-cluster-kafka-2     Bound    pvc-3b1fe485-de86-4b21-8074-622d236226c7   100Gi      RWO            local-path     3m24s
# data-1-my-cluster-kafka-0     Bound    pvc-a1e420cd-7423-441c-b260-dbba5086ea5b   100Gi      RWO            local-path     3m24s
# data-1-my-cluster-kafka-1     Bound    pvc-0cf1d041-e6de-407a-946d-38596961d6e3   100Gi      RWO            local-path     3m24s
# data-1-my-cluster-kafka-2     Bound    pvc-ee22693e-519e-43ed-bef5-c36357262a7d   100Gi      RWO            local-path     3m24s
# data-my-cluster-zookeeper-0   Bound    pvc-7118a2c3-fa31-425c-953d-6774229ca910   100Gi      RWO            local-path     6m4s
# data-my-cluster-zookeeper-1   Bound    pvc-2a8889d9-8366-41df-9163-eb18ea73e01e   100Gi      RWO            local-path     3m51s
# data-my-cluster-zookeeper-2   Bound    pvc-b1360367-326b-44cf-9193-c738e66231fb   100Gi      RWO            local-path     3m51s
```

### Kafka Ephemeral

Since it is not recommended, kafka clusters can be created using `ephemeral` storage.
This method is not suited for production since data will be lost when pods restart.

```bash
# Apply the `Kafka` Cluster CR file (single)
kubectl apply -f examples/kafka/kafka-ephemeral-single.yaml -n kafka 

# Apply the `Kafka` Cluster CR file (HA)
kubectl apply -f examples/kafka/kafka-ephemeral.yaml -n kafka 

# Wait while Kubernetes starts the required pods, services and so on:
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n kafka 
```

### Delete Cluster

To delete the cluster use the following command

```bash
# Delete cluster
kubectl delete kafka/my-cluster -n kafka 
```

## Kafka Topic

Topics can be created using `CRDs`.
It is recommended to disable `auto.create.topics.enable: false` parameter in kafka configuration.

```bash
# Apply the `Kafka` Topic CR file 
kubectl apply -f examples/topic/kafka-topic.yaml -n kafka 

# Get the kafka topics
kubectl get kafkatopic -n kafka
```

## Test

### Topic information

```bash
# Get list of default topics
kubectl -n kafka run kafka-topics -ti --image=quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --rm=true --restart=Never -- bin/kafka-topics.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --list

# Get list of default topics
kubectl -n kafka run kafka-topics -ti --image=quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --rm=true --restart=Never -- bin/kafka-topics.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --describe --topic my-topic
```

### Send and receive messages

Once the cluster is running, you can run a simple producer to send messages to a Kafka topic (the topic will be automatically created):

```bash
kubectl -n kafka run kafka-producer -ti --image=quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --rm=true --restart=Never -- bin/kafka-console-producer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic

# And to receive them in a different terminal you can run:

kubectl -n kafka run kafka-consumer -ti --image=quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --rm=true --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic --from-beginning --consumer-property group.id=my-group
```
