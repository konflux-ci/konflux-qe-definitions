# ROSA HCP Cluster

## ROSA with HCP Prerequisites
https://docs.openshift.com/rosa/rosa_hcp/rosa-hcp-sts-creating-a-cluster-quickly.html#rosa-hcp-prereqs


## How to use the tasks
[Here](../../../integration-test/rhtap/rhtap-installer/pipelines/hcp-cluster-test-pipeline.yaml) is an example about how to use tasks to provision/deprovision ROSA HCP cluster.

### Secrets
You need to create a secret including the following data in Konflux, and pass its name to tasks as parameter `hcp-secrets` 

* AWS_ACCOUNT_ID
* AWS_OIDC_CONFIG_ID
* INSTALL_ROLE_ARN
* OPERATOR_ROLES_PREFIX
* SUBNET_IDS
* SUPPORT_ROLE_ARN
* WORKER_ROLE_ARN
* AWS_ACCESS_KEY_ID
* AWS_SECRET_ACCESS_KEY
* ROSA_TOKEN