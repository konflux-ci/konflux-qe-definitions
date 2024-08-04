## Table of Contents<!-- omit from toc -->

- [Overview](#overview)
- [Requirements](#requirements)
    - [AWS Credentials for ROSA](#aws-credentials-for-rosa)
    - [Pull Request Commenter GitHub Token](#pull-request-commenter-github-token)
- [Adding an Integration Test](#adding-an-integration-test)
- [FAQs](#faqs)
- [Troubleshooting](#troubleshooting)
- [Contact Us](#contact-us)

## Overview

This document is designed to assist QE teams in preparing their testing repositories to run within Konflux CI. We'll cover all necessary preparations and requirements in detail to ensure a smooth integration and testing process.

> **Note:** For any questions or to brainstorm specific solutions, please reach out to us on the Slack channel [#forum-konflux-qe](https://slack.com).

## Requirements

To run integration tests in Konflux, there are several requirements:

1. You have created an **application** in Konflux.
2. **AWS Credentials** for ephemeral ROSA clusters.
3. **GitHub Token** for pull-request commenter. Konflux QE creates a utility in ROSA Deprovision tasks to comment on pull requests after the Integration Test finishes.

> **Note:** Konflux e2e secrets are stored all in vault.devshift. To access the secrets you need to open a Pull Request as the [following](https://github.com/redhat-appstudio/infra-deployments/pull/4255) in infra-deployments.

### AWS Credentials for ROSA

To run ROSA (Red Hat OpenShift Service on AWS) clusters, you need valid AWS credentials. These credentials must have the necessary permissions to create and manage ephemeral ROSA clusters.


### Pull Request Commenter GitHub Token

A GitHub Token is required for Konflux to comment on pull requests. This is used in the ROSA Deprovision tasks to notify the status of integration tests.

**Steps to create a GitHub Token:**

1. Go to your GitHub account settings.
2. Navigate to **Developer settings** > **Personal access tokens**.
3. Click on **Generate new token**.
4. Select the scopes required for commenting on pull requests, such as `repo` and `public_repo`.
5. Generate and securely store the token.

> **Note:** Keep this token secure and do not expose it in your repositories.

## Adding an Integration Test

1. Open your application in Konflux and go to the **Integration tests** tab.
2. Select **Add integration test**.
3. In the **Integration test name** field, enter a name of your choosing.
4. In the **GitHub URL** field, enter the URL of the GitHub repository that contains the test pipeline you want to use.
5. Optional: If you want to use a branch, commit, or version other than the default, specify the branch name, commit SHA, or tag in the **Revisions** field.
6. In the **Path in repository** field, enter the path to the .yaml file that defines the test you want to use.
7. Optional: To allow the integration tests to fail without impacting the release process of your application, you can choose to select **Mark as optional for release**.
8. Select **Add integration test**.
9. To start building a new component, either open a new pull request (PR) that targets the tracked branch of the component in the GitHub repository, or comment '/retest' on an existing PR.

## FAQs

**Q: What is Konflux CI?**
A: WIP.

**Q: How do I secure my AWS credentials and GitHub tokens?**
A: Store them in a secure environment variable manager or secrets manager, and ensure they are not exposed in your codebase.

## Troubleshooting

- **Issue:** Integration test fails to start.
  - **Solution:** Verify that your AWS credentials and GitHub tokens are correctly configured and have the necessary permissions.

- **Issue:** Unable to add a GitHub repository URL.
  - **Solution:** Ensure the URL is correct and accessible, and that you have the required permissions to access the repository.

## Contact Us

For further assistance, feel free to reach out:
