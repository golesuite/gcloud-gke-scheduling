
Alpine-gke-autoscaler-scheduler
===============================

Alpine script used to gcloud cluster resize

# ENV Variables

| ENV Variables | Required | example value |
|---|---|---|
| SCALE_DEPLOY_NUMBER  | X | 0 |
| SCALE_STS_NUMBER  | X | 0 |
| SCALE_NODES_NUMBER  | X | 0 |
| PROJECT_ID   | X | gole |
| CLUSTER_NAME | X | br-gole-01 |
| GCLOUD_ZONE  | X | southamerica-east1-a |
| SCHEDULER_LABEL | X | scheduler=comercial |
| SCHEDULER_POOL | X | pool-qa |
| USE_GKE_GCLOUD_AUTH_PLUGIN | X | True |
