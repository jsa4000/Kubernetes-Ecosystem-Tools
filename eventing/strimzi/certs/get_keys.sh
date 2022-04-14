#!/bin/bash

# ./get_keys.sh <cluster> <namespace> <username> <password>
# ./get_keys.sh my-cluster kafka my-user
# ./get_keys.sh my-cluster kafka my-user 123456

# unsetopt nomatch
rm -f *.crt *.key *.p12 *.jks *.password *.properties *.yaml

export CLUSTER_NAME=${1:-kafka-cluster}
export KAFKA_NAMESPACE=${2:-kafka}
export KAFKA_USER_NAME=${3:-kafka-tls-client-credentials}
export PASSWORD=${4:-}

if [ -z $PASSWORD ]; then
    
    # Get CA information (truststore)
    kubectl get secret $CLUSTER_NAME-cluster-ca-cert -n $KAFKA_NAMESPACE -o jsonpath='{.data.ca\.p12}' | base64 -d > ca.p12
    kubectl get secret $CLUSTER_NAME-cluster-ca-cert -n $KAFKA_NAMESPACE -o jsonpath='{.data.ca\.password}' | base64 -d > ca.password

    # Get User Information (keystore)
    kubectl get secret $KAFKA_USER_NAME -n $KAFKA_NAMESPACE -o jsonpath='{.data.user\.p12}' | base64 -d > user.p12
    kubectl get secret $KAFKA_USER_NAME -n $KAFKA_NAMESPACE -o jsonpath='{.data.user\.password}' | base64 -d > user.password

    TRUSTSTORE_FILE=ca.p12
    TRUSTSTORE_PASSWORD=$(cat ca.password)
    KEYSTORE_FILE=user.p12
    KEYSTORE_PASSWORD=$(cat user.password)
   
else

    # Get CA information (truststore)
    kubectl get secret $CLUSTER_NAME-cluster-ca-cert -n $KAFKA_NAMESPACE -o jsonpath='{.data.ca\.crt}' | base64 --decode > ca.crt

    # Get User Information (keystore)
    kubectl get secret $KAFKA_USER_NAME -n $KAFKA_NAMESPACE -o jsonpath='{.data.user\.crt}' | base64 --decode > user.crt
    kubectl get secret $KAFKA_USER_NAME -n $KAFKA_NAMESPACE -o jsonpath='{.data.user\.key}' | base64 --decode > user.key

    echo "yes" | keytool -import -trustcacerts -file ca.crt -keystore truststore.jks -storepass $PASSWORD
    RANDFILE=/tmp/.rnd openssl pkcs12 -export -in user.crt -inkey user.key -name $KAFKA_USER_NAME -password pass:$PASSWORD -out user.p12

    TRUSTSTORE_FILE=truststore.jks
    TRUSTSTORE_PASSWORD=$PASSWORD
    KEYSTORE_FILE=user.p12
    KEYSTORE_PASSWORD=$PASSWORD
    
fi

# Generate configuration file for client 
envsubst < client.properties.template > client.properties

# Generate secret if needed to be used inside kubernetes cluster
kubectl create secret generic kafka-client --dry-run=client \
 --from-file=$TRUSTSTORE_FILE=$TRUSTSTORE_FILE \
 --from-file=$KEYSTORE_FILE=$KEYSTORE_FILE \
 --from-file=client.properties=client.properties \
 -o yaml > kafka-client-secret.yaml

# Remove all intermediate files
rm -f *.crt *.key *.password