#!/bin/sh

apk add --no-cache curl python3
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-368.0.0-linux-x86_64.tar.gz
tar xzf google-cloud-sdk-336.0.0-linux-x86_64.tar.gz
mv google-cloud-sdk /opt
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/bin

# gcloud auth
/opt/google-cloud-sdk/bin/gcloud auth activate-service-account \
                                 --project=$PROJECT_ID --key-file=/etc/gcloud/key.json
/opt/google-cloud-sdk/bin/gcloud container clusters get-credentials $CLUSTER_NAME \
                                 --zone $GCLOUD_ZONE --project $PROJECT_ID

#ALL_DEPLOY=$(kubectl get -A -l "$SCHEDULER_LABEL" deploy -o=jsonpath='{.items[*].metadata.namespace}:{.items[*].metadata.name}')
#NS=($(echo "$ALL_DEPLOY" | cut -d":" -f 1))
#DEPLOY=($(echo "$ALL_DEPLOY" | cut -d":" -f 2))

ALL_DEPLOY=$(kubectl get -A -l "$SCHEDULER_LABEL" deploy -o=jsonpath='{.items[*].metadata.namespace}' | sort | uniq )

# SCALE_DEPLOY_NUMBER
# SCALE_STS_NUMBER
# SCALE_NODES_NUMER
# CLUSTER_NAME
# GCLOUD_ZONE
for ((i=1; i<${#ALL_DEPLOY}+1; i++)); do 
    kubectl -n "${NS[$i]}" scale deploy -l scheduler=comercial --replicas=${SCALE_DEPLOY_NUMBER}
    kubectl -n "${NS[$i]}" scale sts -l scheduler=comercial --replicas=${SCALE_STS_NUMBER}
done

/opt/google-cloud-sdk/bin/gcloud container clusters resize -q $CLUSTER_NAME \
                                 --node-pool pool-qa --num-nodes $SCALE_NODES_NUMBER \
                                 --zone $GCLOUD_ZONE --project $PROJECT_ID
