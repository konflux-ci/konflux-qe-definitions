# Tekton Task: Test Metadata

This task extracts metadata from a JSON snapshot and logs it for test execution purposes.

## Description

The `test-metadata` task is designed to extract metadata from a JSON snapshot and log it. It provides information such as the event type, Git URL, Git revision, container image, GitHub organization, repository, pull request number, and pull request author. This metadata is useful for tracking and analyzing test executions.

## Parameters

- **SNAPSHOT**: The JSON string of the Snapshot under test. Example of SNAPSHOT: 
- **test-name**: The name of the test being executed.

## Results

The task produces the following results:

1. **test-event-type**: Indicates if the job is triggered by a Pull Request or a Push event.
2. **pull-request-number**: The pull request number if the job is triggered by a pull request event.
3. **git-url**: The Git URL from which the test pipeline is originating. This can be from a fork or the original repository.
4. **git-revision**: The Git revision (commit SHA) from which the test pipeline is originating.
5. **container-image**: The container image built from the specified Git revision.
6. **git-org**: The GitHub organization from which the test is originating.
7. **git-repo**: The repository from which the test is originating.
8. **oras-container**: The ORAS container used to store all test artifacts.
9. **pull-request-author**: The GitHub author of the pull request event.

## Usage

Example usage of the `test-metadata` task in a Tekton Pipeline:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: test-metadata-pipeline
spec:
  tasks:
    - name: extract-metadata
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-qe-incubator/konflux-qe-definitions
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/test-metadata/test-metadata.yaml
      params:
        - name: SNAPSHOT
          value: "<your-snapshot-json>"
        - name: test-name
          value: "<your-test-name>"
```
