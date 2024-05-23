# Register Openshift CLuster backends in Konflux

This guide provides instructions on how to use the `sprayproxy-register-server` and `sprayproxy-unregister-server` Tekton tasks to register and unregister a PAC server with SprayProxy.

## Prerequisites

Before you begin, ensure you have the following:
- Access to Openshift cluster where Openshift Pipelines are installed.
- Access to the `sprayproxy-auth` secret containing the `server-token` and `server-url` keys.
- The `quay.io/konflux-qe-incubator/konflux-qe-tools:latest` image available.

## Tasks

### 1. Registering a PAC Server

The `sprayproxy-register-server` task registers a PAC server with SprayProxy.

#### Parameters

- **ocp-login-command**: The command used to log in to the OpenShift cluster and get the webhook url

### 2. Unregistering a PAC Server

The sprayproxy-unregister-server task unregisters a PAC server from SprayProxy.

#### Parameters
This task does not require any additional parameters.


### Usage

When creating a pipeline, you need to pass the `ocp-login-command` parameter to the `sprayproxy-register-server` task.

Example:
```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: unregister-pac-server-pipeline
spec:
  tasks:
    - name: register-pac-server
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-qe-incubator/konflux-qe-definitions
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/sprayproxy/sprayproxy-provision/sprayproxy-register-server.yaml
      params:
        - name: ocp-login-command
          value: "oc login --token=<your-token> --server=<your-server>"
  finally:
    - name: unregister-pac-server
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-qe-incubator/konflux-qe-definitions
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/sprayproxy/sprayproxy-deprovision/sprayproxy-unregister-server.yaml
