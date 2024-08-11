## Table of Contents

- [Overview](#overview)
- [Adding an Integration Test](#requirements)
- [Cli to generate konflux integration tests](#use-konflux-qe-cli-to-generate-integration-tests)

# Overview

Integration tests ensure that all components within an application are able to work together at the same time. You can add an integration test, simply by giving Konflux the address to a GitHub repo, and the path within that repo to an IntegrationTestScenario (ITS). An ITS is a YAML file, one that contains a Tekton Pipeline that defines an integration test.

Konflux runs integration tests after it successfully builds the various components of an application. As part of the build process, Konflux creates an image for each component and stores them in a repository. Images of all the components are then compiled into a snapshot of the application. Konflux tests the snapshot against user-defined IntegrationTestScenarios, which, again, is a YAML file in a GitHub repository.

# Generate Integration Tests

The Konflux QE team provides a tool to generate integration tests for each Konflux component. This script generates a Tekton pipeline YAML for Konflux integration tests. The generated pipeline automates running the Konflux E2E Framework on a ROSA (Red Hat OpenShift Service on AWS) cluster.

## Usage

- Ensure you have `curl` or `wget` installed on your system.
- Ensure you have write permissions to the target directory where the YAML will be generated.

To generate the integration test pipeline YAML, use the `generate` command:

```bash
# Generate Pipeline script
bash -c "$(curl -fsSL https://raw.githubusercontent.com/konflux-ci/konflux-qe-definitions/main/scripts/konflux-it-generator.sh)" -- generate --target-dir <target-directory> --name <pipeline-name>

```
Will create by default a tekton pipeline ready to run in every component in Konflux. Next sections in the document will help to customize the generated pipeline.

In case you want to create your own custom integration tests please refer to [Konflux Guide](https://konflux-ci.dev/docs/how-tos/testing/integration/creating/).

## Advanced configurations

After generating the Pipeline you can modify the task acordingly to your needs.

### Skip artifacts load to OCI registry

By default tasks like `deprovision-rosa-collect-artifacts` or `pull-request-status-message` pass as param *pipeline-aggregate-status* set to `"$(tasks.status)"`. This param will be take by the tasks and will skip to collect logs or don't comment the pull request with integration test status in case of success.

Example:
```yaml
        - name: pipeline-aggregate-status
          value: "$(tasks.status)"
```

### Konflux component image
In order to test your component code from Pull Request you need to make sure in the Pipeline generated you are passing the following arguments to `konflux-e2e` task:
```yaml
        - name: component-image
          value: "$(tasks.test-metadata.results.container-image)"
```
Is grabing using [test-metadata](../qe-available-tasks/Test-metadata.md) task the result container from the snapshot.

# Add Integration Test to Konflux (via UI)

In Konflux, you can add integration tests to verify that the individual components of your application integrate correctly, forming a complete and functional application. Konflux runs these integration tests on the container images of components before their release.

1. Open your application in Konflux and go to the **Integration tests** tab.
2. Select **Add integration test**.
3. In the **Integration test name** field, enter a name of your choosing.
4. In the **GitHub URL** field, enter the URL of the GitHub repository that contains the test pipeline you want to use.
5. Optional: If you want to use a branch, commit, or version other than the default, specify the branch name, commit SHA, or tag in the **Revisions** field.
6. In the **Path in repository** field, enter the path to the .yaml file that defines the test you want to use.
7. Optional: To allow the integration tests to fail without impacting the release process of your application, you can choose to select **Mark as optional for release**.
8. Select **Add integration test**.
9. To start building a new component, either open a new pull request (PR) that targets the tracked branch of the component in the GitHub repository, or comment '/retest' on an existing PR.

Before clicking on **Create** please configure the necessary params for your Konflux E2E tests, explained in next chapter.

## Configure Konflux E2E parameters

In order to make your Integration Test pipeline to run in Konflux you need to create some params in the UI or cli by modify:

- **konflux-test-infra-secret**: The secret name to allow Integration tests to deploy ephemeral clusters or another operations like pull request comment. Check more details about [*konflux-test-infra-secret*](./Prerequisites_Guide.md). By default is **konflux-test-infra**.

- **cloud-credential-key**. Makes reference to the key from *konflux-test-infra* secret where is stored the AWS credential to deploy ROSA. By default in Konflux vault the secret is created with 2 keys: cloud-credential-key-us-west-2; this one should be used by all konflux components, cloud-credential-key-us-east-2 only used by [infra-deployments](https://github.com/redhat-appstudio/infra-deployments) repo or [e2e](https://github.com/konflux-ci/e2e-tests) repo in Konflux.

- **quality-dashboard-api**. In case quality dashboard task is activated set this param pointing to Quality Dashboard backend to send results. Default is: `https://backend-quality-dashboard.apps.stone-stg-rh01.l2vh.p1.openshiftapps.com`

- **oras-container**. Container where all artifacts will be store tests artifacts from pipelines such as Junit, Cluster artifacts etc. Konflux will use `quay.io/konflux-test-storage` org. Every component need to create a repository in konflux-test-storage. After create the repo, set the para to: `quay.io/konflux-test-storage/<component-name>`.
