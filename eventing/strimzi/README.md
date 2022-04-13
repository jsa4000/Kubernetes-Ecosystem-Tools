# Strimzi

[Strimzi](https://strimzi.io/) provides a way to run an Apache Kafka cluster on Kubernetes in various deployment configurations.

Secure by Default

* Built-in security
* `TLS`, `SCRAM-SHA`, and `OAuth` authentication
* Automated Certificate Management

Simple yet Configurable

* `NodePort`,` Load balancer` and `Ingress` options
* Rack awareness for HA
* Use dedicated nodes for Kafka

Kubernetes-Native Experience

* Use `kubectl` to manage Kafka
* Operator-based (What is an operator?)
* Manage Kafka using GitOps

## [Quick Start](https://strimzi.io/quickstarts/)

### Applying Strimzi installation file

Next we apply the Strimzi install files, including `ClusterRoles`, `ClusterRoleBindings` and some Custom Resource Definitions (`CRDs`). The CRDs define the schemas used for declarative management of the Kafka cluster, Kafka topics and users.

```bash
# Create kafkaa Namespace
kubectl create namespace kafka

# Install strimzi operator using latest release and default configuration
kubectl apply -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka

# Verify resources are installed and ready
kubectl get all -n kafka

# Explain kafka cluster CRDs
kubectl explain 'kafka.spec'
kubectl explain 'kafka.spec.kafka.version'
```

### Provision the Apache Kafka cluster

`Strimzi` needs a simple Custom Resource to create the resources, which will then give you a small *persistent Apache Kafka Cluster* with one node each for Apache Zookeeper and Apache Kafka:

```bash
# Apply the `Kafka` Cluster CR file
kubectl apply -f examples/kafka/kafka-persistent-single.yaml -n kafka 

# Wait while Kubernetes starts the required pods, services and so on:
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n kafka 
```

### Test and list topics

```bash
# Get list of default topics
kubectl -n kafka run kafka-topics -ti --image=quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --rm=true --restart=Never -- bin/kafka-topics.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --list
```

### Send and receive messages

Once the cluster is running, you can run a simple producer to send messages to a Kafka topic (the topic will be automatically created):

```bash
kubectl -n kafka run kafka-producer -ti --image=quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --rm=true --restart=Never -- bin/kafka-console-producer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic

# And to receive them in a different terminal you can run:

kubectl -n kafka run kafka-consumer -ti --image=quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --rm=true --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic --from-beginning
```


