# Security

Strimzi provide a built-in security with automated Certificate Management.

There are several method to use for authenticate `TLS`, `SCRAM-SHA`, and `OAuth`.

## TLS

`TLS` is used to `encrypt` point-to-point communication, to `authenticate` the users and for authorization based on Kafka `ACLs`.

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    version: 3.1.0
    replicas: 3
    listeners:
      - name: tls
        port: 9093
        type: internal
        tls: true # This is used to encrypt the communication
        authentication:
          type: tls # Method for the authentication. Values [tls, scram-sha-512, oauth, custom]
    authorization:
      type: simple # Authorization method. Values [simple, opa,  keycloak, custom]
```

Run the following commands to apply the example

```bash
# Install Strimzi Operator
kubectl create ns kafka
helm install strimzi strimzi/strimzi-kafka-operator -n strimzi --create-namespace --version 0.28.0 --wait \
    --set watchNamespaces='{kafka}'

# Create the kafka cluster with security (Port: 9093), TLS authentication and Simple authorization.
# Create a basic topic (`my-topic`) with 10 partitions and 3 replicas
kubectl apply -f examples/security/tls-auth/kafka.yaml -n kafka
kubectl apply -f examples/security/tls-auth/topic.yaml -n kafka

# OR

# Create kafka cluster single with no HA (all configuration related to replication has set to 1)
# Create a basic topic (`my-topic`) with 10 partitions and 1 replicas
kubectl apply -f examples/security/tls-auth/kafka-single.yaml -n kafka
kubectl apply -f examples/security/tls-auth/topic-single.yaml -n kafka

# Wait until the cluster is created and ready
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n kafka 
kubectl wait kafkatopic/my-topic --for=condition=Ready --timeout=300s -n kafka 

# Get the list of topics available
kubectl get kafkatopic -n kafka

# Since it is encrypted you cannot connect without enabling TLS and verifying using truststore for ca.
#kubectl -n kafka run kafka-producer -ti --image=quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --rm=true --restart=Never -- bin/kafka-console-producer.sh --bootstrap-server my-cluster-kafka-bootstrap:9093 --topic my-topic
```

### User

Depending on the `authorization` and `authentication` type, `KafkaUsers` and permissions can be created in different ways using `sasl`, `ACLS`, `oauth claims s`, etc...

As a general rule, the cations allowed for each user it will depend on the role:

* `Producers` need to have permissions to `write`, `create` (no good practice at all) and `describe` for a particular `topic`.
* `Consumers` need to have access to a particular `group` and a `topic` with `read` and `describe` permissions.

Strimzi allows to define `quotas` to limit user resources.

`user.yaml`

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-user
  labels:
    strimzi.io/cluster: my-cluster
spec:
  authentication:
    type: tls
  authorization:
    type: simple
    acls:
      # Example ACL rules for consuming from my-topic using consumer group my-group
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Read
        host: "*"
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Describe
        host: "*"
      - resource:
          type: group
          name: my-group
          patternType: literal
        operation: Read
        host: "*"
      # Example ACL rules for producing to topic my-topic
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Write
        host: "*"
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Create
        host: "*"
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Describe
        host: "*"
  quotas:
    producerByteRate: 1048576
    consumerByteRate: 2097152
    requestPercentage: 55
    controllerMutationRate: 10

```

You can use different `patternType` and `wildcards (*)` to grant access to `groups` and `topics` for an user.

```yaml
      - resource:
          type: topic
          name: *
          patternType: literal # Values `literal` or `prefix`
        operation: Describe
        host: "*"
      - resource:
          type: group
          name: *
          patternType: literal
        operation: Read
        host: "*"
```

Run the following commands to apply the kafka user examplle

```bash
# Create a basic user (`my-user`) thatt has full access to  consumer group `my-group` and topic `my-topic`.
kubectl apply -f examples/security/tls-auth/user.yaml -n kafka

# Verify user (my-user) has been created
kubectl get kafkauser -n kafka 

# NAME      CLUSTER      AUTHENTICATION   AUTHORIZATION   READY
# my-user   my-cluster   tls              simple          True

# For the user a secret has been created
kubectl get secret -n kafka | grep my-user

# NAME                                     TYPE                                  DATA   AGE
# my-user                                  Opaque                                5      60s

# Since it is  still encripted you cannot connect without enabling TLS and verifying using truststore for ca or user credentials
#kubectl -n kafka run kafka-producer -ti --image=quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --rm=true --restart=Never -- bin/kafka-console-producer.sh --bootstrap-server my-cluster-kafka-bootstrap:9093 --topic my-topic
```

### Credentials

Create a `client.properties.template` file with the following information

```console
security.protocol=SSL
ssl.truststore.location=/tmp/certs/$TRUSTSTORE_FILE
ssl.truststore.password=$TRUSTSTORE_PASSWORD
ssl.keystore.location=/tmp/certs/$KEYSTORE_FILE
ssl.keystore.password=$KEYSTORE_PASSWORD
```

Retrieve credentials from Kafka

```bash
# create certs folder if not exist
mkdir certs

# Remove all files previously created
cd certs
unsetopt nomatch
rm -f *.crt *.key *.p12 *.jks *.password *.properties *.yaml

# Get CA information (truststore)
kubectl get secret my-cluster-cluster-ca-cert -n kafka -o jsonpath='{.data.ca\.p12}' | base64 -d > ca.p12
kubectl get secret my-cluster-cluster-ca-cert -n kafka -o jsonpath='{.data.ca\.password}' | base64 -d > ca.password

# Get User Information (keystore)
kubectl get secret my-user -n kafka -o jsonpath='{.data.user\.p12}' | base64 -d > user.p12
kubectl get secret my-user -n kafka -o jsonpath='{.data.user\.password}' | base64 -d > user.password

export TRUSTSTORE_FILE=ca.p12
export TRUSTSTORE_PASSWORD=$(cat ca.password)
export KEYSTORE_FILE=user.p12
export KEYSTORE_PASSWORD=$(cat user.password)

envsubst < client.properties.template > client.properties

rm -f *.password
```

Generate the credentials inside kubernetes

> Inside the cluster, kafka clients can use directly the previous secrets created bt strimzi with the ca and the user credentials.

```bash
# Create secret using previous files generated since all have sensitive and confidential information
kubectl create secret generic kafka-client --dry-run=client \
 --from-file=ca.p12=ca.p12 \
 --from-file=user.p12=user.p12 \
 --from-file=client.properties=client.properties \
 -o yaml > kafka-client-secret.yaml

# Apply the secret
kubectl apply -n kafka -f kafka-client-secret.yaml
```

Use the script provided in the project to automate this process

```bash
# create certs folder if not exist
cd certs

# ./get_keys.sh <cluster> <namespace> <username> <password>

# Generate the files with the key storages provided by Strimzi
./get_keys.sh my-cluster kafka my-user

# Generate the files with the key storages provided by Strimzi and custom password (not valid for production purposes)
./get_keys.sh my-cluster kafka my-user 123456

# Apply the secret if needed it
kubectl apply -n kafka -f kafka-client-secret.yaml

# Check if it was created
kubectl get secret -n kafka | grep kafka-client
```

## Test

Create a pod to run Kafka topics with secrets mounted to enable SSL communication with kafka.

```bash
# Go to root folder /strimzi
cd ..

# Install yq
export VERSION=v4.24.4
export BINARY=yq_darwin_amd64
wget "https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}" && mv ${BINARY} /usr/local/bin

# Create the function to get the override with the patch to apply to kubectl run
# USAGE: get_override <command> <patch_file>
function get_override() { 
  COMMAND=$(echo $1 | sed -e 's/ /","/g')
  MANIFEST=$(envsubst < $2)
  echo $(echo $MANIFEST | yq -j eval -)
}

export PATCH_FILE='examples/security/tls-auth/client.yaml'

# Get Topic list
export COMMAND='bin/kafka-topics.sh --bootstrap-server my-cluster-kafka-bootstrap:9093 --list --command-config /tmp/certs/client.properties'
kubectl -n kafka run kafka-topic -ti --rm=true --restart=Never --image=quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --overrides="$(get_override $COMMAND $PATCH_FILE)"

# Describe topic `my-topic`
export COMMAND='bin/kafka-topics.sh --bootstrap-server my-cluster-kafka-bootstrap:9093 --describe --topic my-topic --command-config /tmp/certs/client.properties'
kubectl -n kafka run kafka-topic -ti --rm=true --restart=Never --image=quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --overrides="$(get_override $COMMAND $PATCH_FILE)"

```

Subscribe and Publish messages

```bash

# Create the function to get the override with the patch to apply to kubectl run
# USAGE: get_override <command> <patch_file>
function get_override() { 
  COMMAND=$(echo $1 | sed -e 's/ /","/g')
  MANIFEST=$(envsubst < $2)
  echo $(echo $MANIFEST | yq -j eval -)
}

export PATCH_FILE='/Users/jsantosa/Projects/Github/Kubernetes-Ecosystem-Tools/eventing/strimzi/examples/security/tls-auth/client.yaml'

# Publish to a topic topic `my-topic`
export COMMAND='bin/kafka-console-producer.sh --broker-list my-cluster-kafka-bootstrap:9093 --topic my-topic --producer.config /tmp/certs/client.properties'
kubectl -n kafka run kafka-publisher -ti --rm=true --restart=Never --image=quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --overrides="$(get_override $COMMAND $PATCH_FILE)"

# Open new terminal

# Consume from a topic topic `my-topic`
export COMMAND='bin/kafka-console-consumer.sh --bootstrap-server my-cluster-kafka-bootstrap:9093 --topic my-topic --consumer-property group.id=my-group --from-beginning --consumer.config /tmp/certs/client.properties'
kubectl -n kafka run kafka-consumer -ti --rm=true --restart=Never --image=quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --overrides="$(get_override $COMMAND $PATCH_FILE)"
```

## SCRAM-SHA-512

See the `examples/security/keycloak-authorization` example to get the needed configuration for the `Kafka cluster`, `Users` and `Topics`.

## KEYCLOAK

See the `examples/security/scram-sha-512-auth` example to get the needed configuration for the `Kafka cluster`, `Users` and `Topics`.
