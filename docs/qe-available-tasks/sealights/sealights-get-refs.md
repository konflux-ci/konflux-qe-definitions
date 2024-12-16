# Sealights Get Refs Tekton Task

## Overview

The `sealights-get-refs` Tekton Task is designed to retrieve metadata related to Sealights instrumentation in a CI pipeline. This Task extracts key information, such as the Sealights Build Session ID, the source artifact type, the instrumented container image, and the build name. It does so by processing attestation data associated with a container image using `cosign`.

## Task Description

The Task performs the following steps:
1. Retrieves the container image associated with the specified component from the provided `SNAPSHOT` parameter.
2. Downloads the attestation metadata using `cosign`.
3. Parses the attestation metadata to extract Sealights-related information.
4. Writes the extracted information to Tekton Task results.

## Parameters

| Name       | Type   | Description                                  |
|------------|--------|----------------------------------------------|
| `SNAPSHOT` | string | The JSON string representing the Snapshot under test. |

## Results

| Name                         | Description                                                                     |
|-------------------------------|---------------------------------------------------------------------------------|
| `sealights-source-artifact`  | Indicates if the job was triggered by a Pull Request or a Push event.          |
| `sealights-bsid`             | The Build Session ID (BSID) if the job is triggered by a pull request.         |
| `sealights-container-image`  | The container image used in the Sealights instrumentation process.             |
| `sealights-build-name`       | The Git revision (commit SHA) associated with the test pipeline.               |
| `container-image`            | The container image built from the specified Git revision without Sealights instrumentation. |

## Steps

The Task has a single step:

### Step: `sealights-get-refs`

- **Image**: `quay.io/konflux-qe-incubator/konflux-qe-tools:latest`

## Usage Example

Here's an example of how to use the `sealights-get-refs` Task in a Tekton Pipeline:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: example-sealights-pipeline
spec:
  params:
    - name: snapshot
      description: "The Snapshot JSON string"
  tasks:
    - name: get-sealights-refs
      taskRef:
        name: sealights-get-refs
      params:
        - name: SNAPSHOT
          value: "$(params.snapshot)"
```
