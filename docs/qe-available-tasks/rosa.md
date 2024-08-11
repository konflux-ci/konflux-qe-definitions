# Konflux Rosa Provision

This repository contains Tekton tasks for managing [Openshift Rosa with HCP](https://docs.openshift.com/rosa/rosa_hcp/rosa-hcp-sts-creating-a-cluster-quickly.html) clusters in AWS.

## Generate Openshift Rosa Cluster Name

This [task](./rosa-hcp-metadata/rosa-hcp-metadata.yaml) generates the name for the Openshift Rosa cluster.

### Parameters

This task does not have any parameters.

### Results

- **cluster-name**: The generated name for the Openshift cluster.

### Steps

1. **generate-cluster-name**: Generates a unique cluster name using a prefix and a random hex string. It then outputs the cluster name to the specified result path.

## Provision Rosa with HCP Cluster in AWS

This [task](./rosa-hcp-provision/rosa-hcp-provision.yaml) provisions an Openshift Rosa with HCP cluster in AWS.

### Parameters

- **ocp-version**: The version of the OpenShift Container Platform (OCP) to deploy.
- **cluster-name**: The name of the OpenShift cluster to be created.
- **machine-type**: The type of AWS EC2 instance to use for the cluster nodes.
- **replicas**: The number of worker nodes to provision in the cluster (default: 3).
- **konflux-test-infra-secret**: The name of secret where testing infrastructures credentials are stored..
- **cloud-credential-key**: The key secret from konflux-test-infra-secret where all AWS ROSA configurations are stored. You can refer to this [link](https://docs.openshift.com/rosa/rosa_hcp/rosa-hcp-sts-creating-a-cluster-quickly.html#rosa-hcp-prereqs) to create AWS resources

### Results

- **ocp-login-command**: Command to log in to the newly ephemeral OpenShift cluster.

### Steps

1. **provision**: Configures AWS credentials and provisions the Openshift Rosa cluster. It sets up necessary environment variables and executes the provisioning commands.

## Deprovision Rosa with HCP Cluster in AWS

This [task](./rosa-hcp-deprovision/rosa-hcp-deprovision.yaml) deprovisions an existing Openshift Rosa cluster in AWS. To save time,it won't wait until HCP cluster is fully deprovisioned.

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
- **konflux-test-infra-secret**: The name of secret where testing infrastructures credentials are stored.
- **cloud-credential-key**: The key secret from konflux-test-infra-secret where all AWS ROSA configurations are stored. You can refer to this [link](https://docs.openshift.com/rosa/rosa_hcp/rosa-hcp-sts-creating-a-cluster-quickly.html#rosa-hcp-prereqs) to create AWS resources

#### AWS Credential Secret

You need to create a secret including the following data in Konflux, and pass its name to tasks as parameter `aws-credential-secret` 

```
apiVersion: v1
kind: Secret
metadata:
  name: <REPLACE_ME>
data:
  AWS_ACCESS_KEY_ID: <REPLACE_ME>
  AWS_ACCOUNT_ID: <REPLACE_ME>
  AWS_SECRET_ACCESS_KEY: <REPLACE_ME>
type: Opaque
```

### Setting Up Infrastructure Credentials

**Infrastructure credentials** are stored in the vault with the name `konflux-test-infra`. If your team is not part of Konflux, create your own **Infrastructure credentials** in the vault using this structure as a reference:

**github-bot-commenter-token**: "ey...."

**cloud-credential-{*aws-region*}**:
```json
{
  "aws": {
    "region": "us-east-2",
    "access-key-secret": "none",
    "access-key-id": "none",
    "aws-account-id": "none",
    "rosa-hcp": {
      "rosa-token": "ey....",
      "aws-oidc-config-id": "none",
      "operator-roles-prefix": "none",
      "subnets-ids": "none",
      "install-role-arn": "none",
      "support-role-arn": "none",
      "worker-role-arn": "none"
    }
  }
}
```

To get all the values from rosa-hcp key please Red Hat [documentation](https://docs.openshift.com/rosa/rosa_hcp/rosa-hcp-sts-creating-a-cluster-quickly.html).

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
  params:
    - name: SNAPSHOT
      description: 'The JSON string representing the snapshot of the application under test.'
      default: '{"components": [{"name":"test-app", "containerImage": "quay.io/example/repo:latest"}]}'
      type: string
    - name: test-name
      description: 'The name of the test corresponding to a defined Konflux integration test.'
      default: ''
    - name: ocp-version
      description: 'The OpenShift version to use for the ephemeral cluster deployment.'
      type: string
    - name: test-event-type
      description: 'Indicates if the test is triggered by a Pull Request or Push event.'
      default: 'none'
    - name: konflux-test-infra-secret
      description: The name of secret where testing infrastructures credentials are stored..
      type: string
      default: 'aws-credential-hacbs-dev'
    - name: hcp-config-secret
      type: string
      description: The key secret from konflux-test-infra-secret where all AWS ROSA configurations are stored.
      default: 'cloud-credential-key'
    - name: replicas
      description: 'The number of replicas for the cluster nodes.'
      default: '3'
    - name: machine-type
      description: 'The type of machine to use for the cluster nodes.'
      default: 'm5.2xlarge'
    - name: oras-container
      default: 'quay.io/konflux-qe-incubator/konflux-qe-oci-storage'
      description: The ORAS container used to store all test artifacts.
  tasks:
    - name: rosa-hcp-metadata
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/konflux-qe-definitions.git
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/rosa/hosted-cp/rosa-hcp-metadata/rosa-hcp-metadata.yaml
    - name: provision-rosa
      runAfter:
        - rosa-hcp-metadata
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/konflux-qe-definitions.git
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/rosa/hosted-cp/rosa-hcp-provision/rosa-hcp-provision.yaml
      params:
        - name: cluster-name
          value: "$(tasks.rosa-hcp-metadata.results.cluster-name)"
        - name: ocp-version
          value: "$(params.ocp-version)"
        - name: replicas
          value: "$(params.replicas)"
        - name: machine-type
          value: "$(params.machine-type)"
        - name: aws-credential-secret
          value: "$(params.aws-credential-secret)"
        - name: hcp-config-secret
          value: "$(params.hcp-config-secret)"
    - name: deprovision-rosa-collect-artifacts
      runAfter:
        - provision-rosa
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/konflux-qe-definitions.git
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
        - name: aws-credential-secret
          value: "$(params.aws-credential-secret)"
        - name: hcp-config-secret
          value: "$(params.hcp-config-secret)"
```
