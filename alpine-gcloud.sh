#!/bin/bash

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

#
if [ -z ${APPLICATION_PATH+x} ]; then
    echo "APPLICATION_PATH Env variable is unset"
    exit 1
fi
if [ -z ${SCALE_MODE+x} ]; then
    echo "SCALE_MODE Env variable is unset"
    exit 1
fi
if [ -z ${ENVIRONMENT+x} ]; then
    echo "ENVIRONMENT Env variable is unset"
    exit 1
fi 

set -x

apk add --no-cache curl python3 git
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-481.0.0-linux-x86_64.tar.gz
tar xzf google-cloud-cli-481.0.0-linux-x86_64.tar.gz
mv google-cloud-sdk /opt
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/bin
ln -s /opt/google-cloud-sdk/bin/gcloud /usr/local/bin/

# gcloud auth
/opt/google-cloud-sdk/bin/gcloud components install gke-gcloud-auth-plugin
/opt/google-cloud-sdk/bin/gcloud auth activate-service-account \
                                 --project=$PROJECT_ID --key-file=/etc/gcloud/key.json
/opt/google-cloud-sdk/bin/gcloud container clusters get-credentials $CLUSTER_NAME \
                                 --internal-ip \
                                 --zone $GCLOUD_ZONE --project $PROJECT_ID

resize_cluster(){
    /opt/google-cloud-sdk/bin/gcloud container clusters resize -q $CLUSTER_NAME \
                                     --node-pool $SCHEDULER_POOL --num-nodes $SCALE_NODES_NUMBER \
                                     --zone $GCLOUD_ZONE --project $PROJECT_ID
}

resize_deploys(){
    ALL_DEPLOY=($(kubectl get -A -l "$SCHEDULER_LABEL" deploy -o=jsonpath='{.items[*].metadata.namespace}' | tr " " "\n" | sort | uniq ))
    if test "${#ALL_DEPLOY}" -gt 0; then
        NS=($(echo "${ALL_DEPLOY[*]}" | sort | uniq | cut -d":" -f 1))
        for i in "${NS[*]}"; do
            kubectl -n "$i" scale deploy -l $SCHEDULER_LABEL --replicas=${SCALE_DEPLOY_NUMBER}
        done
    fi
}

resize_sts(){
    STS=($(kubectl get -A -l "$SCHEDULER_LABEL" sts -o=jsonpath='{.items[*].metadata.namespace}' | sort | uniq ))
    if test "${#ALL_STS}" -gt 0; then
        NS=($(echo "${ALL_STS[*]}" | cut -d":" -f 1))
        for i in "${NS[*]}"; do
            kubectl -n $i scale sts -l $SCHEDULER_LABEL --replicas=${SCALE_STS_NUMBER}
        done
    fi
}

repo_clone(){
    cd /tmp
    git clone -b "$BRANCH" $REPO_ADDRESS
    ls
    echo "$REPO_ADDRESS cloned!"
}

delete_applications(){
    cd /tmp$APPLICATION_PATH
    kubectl delete -f "all-apps-$ENVIRONMENT.yaml"
   # find  . | grep application.yaml | grep $ENVIRONMENT| awk '{print "kubectl delete -f " $1 }' | sh
}

create_applications(){
    cd /tmp$APPLICATION_PATH
    kubectl apply -f  "all-apps-$ENVIRONMENT.yaml"
   # find  . | grep application.yaml | grep $ENVIRONMENT| awk '{print "kubectl apply -f " $1 }' | sh
}

scale_extra_services(){
    # external
    kubectl -n external scale deploy postgres-qa --replicas=${SCALE_DEPLOY_NUMBER}
    kubectl -n external scale deploy redis-qa --replicas=${SCALE_DEPLOY_NUMBER}

    # ingress-nginx-qa
    kubectl -n ingress-nginx-qa scale deploy ingress-nginx-qa-controller --replicas=${SCALE_DEPLOY_NUMBER}

    # elastic-qa
    kubectl -n elastic-qa scale sts eck-mmp5-qa-es-eck-qa-data-nodes --replicas=${SCALE_STS_NUMBER}
    kubectl -n elastic-qa scale sts eck-mmp5-qa-es-eck-qa-master-nodes --replicas=${SCALE_STS_NUMBER}
}

if test "$SCALE_MODE" -eq "0"; then
    repo_clone;
    delete_applications;
    scale_extra_services;
    sleep 60;
    resize_cluster;
else
    resize_cluster;
    sleep 60;
    scale_extra_services;
    repo_clone;
    create_applications;
fi

# first resize cluster then create pods
#if test "$SCALE_NODES_NUMBER" -eq "0"; then
#    resize_deploys;
#    resize_sts;
#    sleep 60;
#    resize_cluster;
#else
#    resize_cluster;
#    resize_deploys;
#    resize_sts;
#fi
