# Konflux Rosa Provision

This repository contains Tekton tasks for managing Openshift Rosa clusters in AWS.

## Generate Openshift Rosa Cluster Name

This task generates the name for the Openshift Rosa cluster.

### Parameters

This task does not have any parameters.

### Results

- **cluster-name**: The generated name for the Openshift cluster.

### Steps

1. **generate-cluster-name**: Generates a unique cluster name using a prefix and a random hex string. It then outputs the cluster name to the specified result path.

## Create Openshift Rosa Cluster in AWS

This task provisions an Openshift Rosa cluster in AWS.

### Parameters

- **ocp-version**: The version of the OpenShift Container Platform (OCP) to deploy.
- **region**: The AWS region where the OpenShift cluster will be created.
- **cluster-name**: The name of the OpenShift cluster to be created.
- **machine-type**: The type of AWS EC2 instance to use for the cluster nodes.
- **replicas**: The number of worker nodes to provision in the cluster (default: 3).
- **aws-secrets**: The secret containing the AWS credentials and other necessary details for cluster provisioning.

### Results

- **ocp-login-command**: Command to log in to the newly ephemeral OpenShift cluster.

### Steps

1. **provision**: Configures AWS credentials and provisions the Openshift Rosa cluster. It sets up necessary environment variables and executes the provisioning commands.

## Deprovision Openshift Rosa Cluster in AWS

This task deprovisions an existing Openshift Rosa cluster in AWS.

### Parameters

- **test-name**: The name of the test being executed.
- **ocp-login-command**: Command to log in to the OpenShift cluster.
- **oras-container**: The ORAS container registry URI to store artifacts.
- **pull-request-author**: The GitHub username of the pull request author.
- **git-revision**: The Git revision (commit SHA) of the current build.
- **pull-request-number**: The number of the GitHub pull request.
- **git-repo**: The name of the GitHub repository.
- **git-org**: The GitHub organization or user that owns the repository.
- **cluster-name**: The name of the OpenShift cluster to be deleted.
- **region**: The AWS region where the OpenShift cluster is located.
- **aws-secrets**: The secret containing AWS credentials.

#### AWS secrets

You need to create a secret including the following data in Konflux, and pass its name to tasks as parameter `aws-secrets` 

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

### Steps

1. **collect-artifacts**: Collects artifacts from the OpenShift cluster.
2. **inspect-upload-artifacts**: Inspects artifacts for secrets and uploads them to the ORAS container registry if safe.
3. **pull-request-comment**: Posts a comment on the GitHub pull request with test results and artifact inspection instructions.
4. **deprovision-rosa**: Destroys the Openshift Rosa cluster. It logs in to the Red Hat account, configures AWS credentials, and triggers the deletion of the cluster without waiting for it to be completely deleted.

## Example

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: rosa-konflux
spec:
  tasks:
    - name: rosa-hcp-metadata
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-qe-incubator/konflux-qe-definitions.git
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/rosa/hosted-cp/rosa-hcp-metadata/rosa-hcp-metadata.yaml
    - name: provision-rosa
      runAfter:
        - rosa-hcp-metadata
        - <test-metadata-task-name>
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-qe-incubator/konflux-qe-definitions.git
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/rosa/hosted-cp/rosa-hcp-provision/rosa-hcp-provision.yaml
      params:
        - name: cluster-name
          value: "$(tasks.rosa-hcp-metadata.results.cluster-name)"
        - name: ocp-version
          value: "$(params.ocp-version)"
        - name: region
          value: "$(params.region)"
        - name: replicas
          value: "$(params.replicas)"
        - name: machine-type
          value: "$(params.machine-type)"
        - name: aws-secrets
          value: "$(params.aws-secrets)"
    - name: deprovision-rosa-collect-artifacts
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-qe-incubator/konflux-qe-definitions.git
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/rosa/hosted-cp/rosa-hcp-deprovision/rosa-hcp-deprovision.yaml
      params:
        - name: test-name
          value: $(context.pipelineRun.name)
        - name: ocp-login-command
          value: "$(tasks.provision-rosa.results.ocp-login-command)"
        - name: oras-container
          value: "$(tasks.test-metadata.results.oras-container)"
        - name: pull-request-author
          value: "$(tasks.test-metadata.results.pull-request-author)"
        - name: git-revision
          value: "$(tasks.test-metadata.results.git-revision)"
        - name: pull-request-number
          value: "$(tasks.test-metadata.results.pull-request-number)"
        - name: git-repo
          value: "$(tasks.test-metadata.results.git-repo)"
        - name: git-org
          value: "$(tasks.test-metadata.results.git-org)"
        - name: cluster-name
          value: "$(tasks.rosa-hcp-metadata.results.cluster-name)"
        - name: region
          value: "$(params.region)"
        - name: aws-secrets
          value: "$(params.aws-secrets)"
```