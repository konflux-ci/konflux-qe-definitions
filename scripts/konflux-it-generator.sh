#!/bin/bash

# Script Name: konflux-it-generator.sh
# Description: Bash CLI to help generate Konflux integration test pipeline YAML.

# Function to display help message
show_help() {
    echo "Usage: $0 [option...] {generate}" >&2
    echo
    echo "   -h, --help            Show help"
    echo "   generate              Generate integration test pipeline YAML"
    echo
}

show_generate_help() {
    echo "Usage: $0 generate --target-dir DIR [--name NAME]" >&2
    echo
    echo "   --target-dir DIR  Specify the directory where the YAML will be generated"
    echo "   --name NAME       Specify the name for the pipeline in the YAML"
    echo
}

generate_yaml() {
    local target_dir=$1
    local pipeline_name=${2:-konflux-e2e-tests}

    if [ -z "$target_dir" ]; then
        echo "Error: --target-dir is required"
        show_generate_help
        exit 1
    fi

    if [ ! -d "$target_dir" ]; then
        echo "Error: Directory $target_dir does not exist"
        exit 1
    fi

    if [ ! -w "$target_dir" ]; then
        echo "Error: Directory $target_dir is not writable"
        exit 1
    fi

    local yaml_file="$target_dir/$pipeline_name.yaml"

    echo "Generating integration test pipeline YAML in $yaml_file..."
    cat << EOF > "$yaml_file"
---
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: $pipeline_name
spec:
  description: |-
    This pipeline automates the process of running end-to-end tests for Konflux
    using a ROSA (Red Hat OpenShift Service on AWS) cluster. The pipeline provisions
    the ROSA cluster, installs Konflux using the infra-deployments, runs the tests, collects artifacts,
    and finally deprovisions the ROSA cluster.
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
      description: The name of secret where testing infrastructures credentials are stored.
      type: string
    - name: cloud-credential-key
      type: string
      description: The key secret from konflux-test-infra-secret where all AWS ROSA configurations are stored.
    - name: replicas
      description: 'The number of replicas for the cluster nodes.'
      type: string
    - name: machine-type
      description: 'The type of machine to use for the cluster nodes.'
      type: string
    - name: oras-container
      default: 'quay.io/konflux-ci/konflux-qe-oci-storage'
      description: The ORAS container used to store all test artifacts.
    - name: quality-dashboard-api
      default: 'none'
      description: 'Contains the url of the backend to send metrics for quality purposes.'
    - name: component-image
      default: 'none'
      description: 'Container image built from any konflux git repo. Use this param only when you run Konflux e2e tests
        in another Konflux component repo. Will pass the component built image from the snapshot.'
    - name: container-image
      default: 'quay.io/redhat-user-workloads/konflux-qe-team-tenant/konflux-e2e/konflux-e2e-tests:latest'
      description: 'Konflux e2e tests container. Contain the ginkgo binary to run the e2e tests in any Konflux component.'
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
    - name: test-metadata
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/konflux-qe-definitions.git
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/test-metadata/0.1/test-metadata.yaml
      params:
        - name: SNAPSHOT
          value: \$(params.SNAPSHOT)
        - name: oras-container
          value: \$(params.oras-container)
        - name: test-name
          value: \$(context.pipelineRun.name)
    - name: provision-rosa
      when:
        - input: "\$(tasks.test-metadata.results.test-event-type)"
          operator: in
          values: ["pull_request"]
      runAfter:
        - rosa-hcp-metadata
        - test-metadata
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
          value: "\$(tasks.rosa-hcp-metadata.results.cluster-name)"
        - name: ocp-version
          value: "\$(params.ocp-version)"
        - name: replicas
          value: "\$(params.replicas)"
        - name: machine-type
          value: "\$(params.machine-type)"
        - name: konflux-test-infra-secret
          value: "\$(params.konflux-test-infra-secret)"
        - name: cloud-credential-key
          value: "\$(params.cloud-credential-key)"
    - name: konflux-e2e-tests
      timeout: 2h
      when:
        - input: "\$(tasks.test-metadata.results.test-event-type)"
          operator: in
          values: ["pull_request"]
      runAfter:
        - provision-rosa
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/e2e-tests.git
          - name: revision
            value: main
          - name: pathInRepo
            value: integration-tests/tasks/konflux-e2e-tests-task.yaml
      params:
        - name: test-name
          value: "\$(context.pipelineRun.name)"
        - name: git-repo
          value: "\$(tasks.test-metadata.results.git-repo)"
        - name: git-url
          value: "\$(tasks.test-metadata.results.git-url)"
        - name: git-revision
          value: "\$(tasks.test-metadata.results.git-revision)"
        - name: oras-container
          value: "\$(tasks.test-metadata.results.oras-container)"
        - name: job-spec
          value: "\$(tasks.test-metadata.results.job-spec)"
        - name: ocp-login-command
          value: "\$(tasks.provision-rosa.results.ocp-login-command)"
        - name: component-image
          value: "\$(tasks.test-metadata.results.container-image)"
        - name: container-image
          value: "\$(params.container-image)"
  finally:
    - name: deprovision-rosa-collect-artifacts
      when:
        - input: "\$(tasks.test-metadata.results.test-event-type)"
          operator: in
          values: ["pull_request"]
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/flacatus/konflux-qe-definitions.git
          - name: revision
            value: vault_creds
          - name: pathInRepo
            value: common/tasks/rosa/hosted-cp/rosa-hcp-deprovision/rosa-hcp-deprovision.yaml
      params:
        - name: test-name
          value: "\$(context.pipelineRun.name)"
        - name: ocp-login-command
          value: "\$(tasks.provision-rosa.results.ocp-login-command)"
        - name: oras-container
          value: "\$(tasks.test-metadata.results.oras-container)"
        - name: pull-request-author
          value: "\$(tasks.test-metadata.results.pull-request-author)"
        - name: git-revision
          value: "\$(tasks.test-metadata.results.git-revision)"
        - name: pull-request-number
          value: "\$(tasks.test-metadata.results.pull-request-number)"
        - name: git-repo
          value: "\$(tasks.test-metadata.results.git-repo)"
        - name: git-org
          value: "\$(tasks.test-metadata.results.git-org)"
        - name: cluster-name
          value: "\$(tasks.rosa-hcp-metadata.results.cluster-name)"
        - name: konflux-test-infra-secret
          value: "\$(params.konflux-test-infra-secret)"
        - name: cloud-credential-key
          value: "\$(params.cloud-credential-key)"
        - name: pipeline-aggregate-status
          value: "\$(tasks.status)"
    - name: quality-dashboard-upload
      when:
        - input: "\$(tasks.test-metadata.results.test-event-type)"
          operator: in
          values: ["pull_request"]
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/konflux-qe-definitions.git
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/quality-dashboard/0.1/quality-dashboard-upload.yaml
      params:
        - name: test-name
          value: "\$(context.pipelineRun.name)"
        - name: oras-container
          value: "\$(tasks.test-metadata.results.oras-container)"
        - name: quality-dashboard-api
          value: \$(params.quality-dashboard-api)
        - name: pipeline-aggregate-status
          value: "\$(tasks.status)"
        - name: test-event-type
          value: "\$(tasks.test-metadata.results.test-event-type)"
    - name: pull-request-status-message
      when:
        - input: "\$(tasks.test-metadata.results.test-event-type)"
          operator: in
          values: ["pull_request"]
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/konflux-qe-definitions.git
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/pull-request-comment/0.1/pull-request-comment.yaml
      params:
        - name: test-name
          value: "\$(context.pipelineRun.name)"
        - name: oras-container
          value: "\$(tasks.test-metadata.results.oras-container)"
        - name: pipeline-aggregate-status
          value: "\$(tasks.status)"
        - name: pull-request-author
          value: "\$(tasks.test-metadata.results.pull-request-author)"
        - name: pull-request-number
          value: "\$(tasks.test-metadata.results.pull-request-number)"
        - name: git-repo
          value: "\$(tasks.test-metadata.results.git-repo)"
        - name: git-org
          value: "\$(tasks.test-metadata.results.git-org)"
        - name: git-revision
          value: "\$(tasks.test-metadata.results.git-revision)"
EOF

    echo "YAML file generated successfully."
}

# Parse command-line arguments
case "$1" in
    -h|--help)
        show_help
        ;;
    generate)
        shift
        while [ $# -gt 0 ]; do
            case "$1" in
                --target-dir)
                    TARGET_DIR="$2"
                    shift 2
                    ;;
                --name)
                    PIPELINE_NAME="$2"
                    shift 2
                    ;;
                *)
                    echo "Unknown option: $1"
                    show_generate_help
                    exit 1
                    ;;
            esac
        done
        generate_yaml "$TARGET_DIR" "$PIPELINE_NAME"
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
