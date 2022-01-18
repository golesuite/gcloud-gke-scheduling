#!/bin/sh

set -x

if [ -z ${GCLOUD_ZONE+x} ]; then
    echo "GCLOUD_ZONE Env variable is unset"
    exit 1
fi

if [ -z ${CLUSTER_NAME+x} ]; then
    echo "CLUSTER_NAME Env variable is unset"
    exit 1
fi

if [ -z ${PROJECT_ID+x} ]; then
    echo "PROJECT_ID Env variable is unset"
    exit 1
fi

if [ -z ${SCALE_NODES_NUMBER+x} ]; then
    echo "SCALE_NODES_NUMBER Env variable is unset"
    exit 1
fi

if [ -z ${SCALE_STS_NUMBER+x} ]; then
    echo "SCALE_STS_NUMBER Env variable is unset"
    exit 1
fi

if [ -z ${SCALE_DEPLOY_NUMBER+x} ]; then
    echo "SCALE_DEPLOY_NUMBER Env variable is unset"
    exit 1
fi

if [ -z ${SCHEDULER_POOL+x} ]; then
    echo "SCHEDULER_POOL Env variable is unset"
    exit 1
fi

if [ -z ${SCHEDULER_LABEL+x} ]; then
    echo "SCHEDULER_LABEL Env variable is unset"
    exit 1
elif ! [[ "$SCHEDULER_LABEL" =~ "=" ]]; then
    echo "$SCHEDULER_LABEL Env variable don't contains key=value structure "
    exit 1
fi

apk add --no-cache curl python3
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-368.0.0-linux-x86_64.tar.gz
tar xzf google-cloud-sdk-368.0.0-linux-x86_64.tar.gz
mv google-cloud-sdk /opt
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/bin

# gcloud auth
/opt/google-cloud-sdk/bin/gcloud auth activate-service-account \
                                 --project=$PROJECT_ID --key-file=/etc/gcloud/key.json
/opt/google-cloud-sdk/bin/gcloud container clusters get-credentials $CLUSTER_NAME \
                                 --internal-ip \
                                 --zone $GCLOUD_ZONE --project $PROJECT_ID

ALL_DEPLOY=$(kubectl get -A -l "$SCHEDULER_LABEL" deploy -o=jsonpath='{.items[*].metadata.namespace}' | sort | uniq )
if test "${#ALL_DEPLOY}" -gt 0; then
    for ((i=1; i<${#ALL_DEPLOY}+1; i++)); do
        kubectl -n "${NS[$i]}" scale deploy -l $SCHEDULER_LABEL --replicas=${SCALE_DEPLOY_NUMBER}
    done
fi

ALL_STS=$(kubectl get -A -l "$SCHEDULER_LABEL" sts -o=jsonpath='{.items[*].metadata.namespace}' | sort | uniq )
if test "${#ALL_STS}" -gt 0; then
    for ((i=1; i<${#ALL_STS}+1; i++)); do
        kubectl -n "${NS[$i]}" scale sts -l $SCHEDULER_LABEL --replicas=${SCALE_STS_NUMBER}
    done
fi

/opt/google-cloud-sdk/bin/gcloud container clusters resize -q $CLUSTER_NAME \
                                 --node-pool $SCHEDULER_POOL --num-nodes $SCALE_NODES_NUMBER \
                                 --zone $GCLOUD_ZONE --project $PROJECT_ID
