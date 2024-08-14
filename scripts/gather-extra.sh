#!/bin/bash
function queue() {
  local TARGET="${1}"
  shift
  local LIVE
  LIVE="$(jobs | wc -l)"
  while [[ "${LIVE}" -ge 45 ]]; do
    sleep 1
    LIVE="$(jobs | wc -l)"
  done
  echo "${@}"
  if [[ -n "${FILTER:-}" ]]; then
    "${@}" | "${FILTER}" >"${TARGET}" &
  else
    "${@}" >"${TARGET}" &
  fi
}

export ARTIFACT_DIR="${ARTIFACT_DIR:-.}"

# Ensure the directory exists
mkdir -p "$ARTIFACT_DIR"

echo "Gathering artifacts ..."
mkdir -p ${ARTIFACT_DIR}/pods

oc --insecure-skip-tls-verify --request-timeout=5s get nodes -o jsonpath --template '{range .items[*]}{.metadata.name}{"\n"}{end}' > /tmp/nodes
oc --insecure-skip-tls-verify --request-timeout=5s get pods --all-namespaces --template '{{ range .items }}{{ $name := .metadata.name }}{{ $ns := .metadata.namespace }}{{ range .spec.containers }}-n {{ $ns }} {{ $name }} -c {{ .name }}{{ "\n" }}{{ end }}{{ range .spec.initContainers }}-n {{ $ns }} {{ $name }} -c {{ .name }}{{ "\n" }}{{ end }}{{ end }}' > /tmp/containers
oc --insecure-skip-tls-verify --request-timeout=5s get pods -l openshift.io/component=api --all-namespaces --template '{{ range .items }}-n {{ .metadata.namespace }} {{ .metadata.name }}{{ "\n" }}{{ end }}' > /tmp/pods-api

queue ${ARTIFACT_DIR}/apiservices.json oc --insecure-skip-tls-verify --request-timeout=5s get apiservices -o json
queue ${ARTIFACT_DIR}/clusteroperators.json oc --insecure-skip-tls-verify --request-timeout=5s get clusteroperators -o json
queue ${ARTIFACT_DIR}/clusterversion.json oc --insecure-skip-tls-verify --request-timeout=5s get clusterversion -o json
queue ${ARTIFACT_DIR}/configmaps.json oc --insecure-skip-tls-verify --request-timeout=5s get configmaps --all-namespaces -o json
queue ${ARTIFACT_DIR}/credentialsrequests.json oc --insecure-skip-tls-verify --request-timeout=5s get credentialsrequests --all-namespaces -o json
queue ${ARTIFACT_DIR}/csr.json oc --insecure-skip-tls-verify --request-timeout=5s get csr -o json
queue ${ARTIFACT_DIR}/endpoints.json oc --insecure-skip-tls-verify --request-timeout=5s get endpoints --all-namespaces -o json
FILTER=gzip queue ${ARTIFACT_DIR}/deployments.json.gz oc --insecure-skip-tls-verify --request-timeout=5s get deployments --all-namespaces -o json
FILTER=gzip queue ${ARTIFACT_DIR}/daemonsets.json.gz oc --insecure-skip-tls-verify --request-timeout=5s get daemonsets --all-namespaces -o json
queue ${ARTIFACT_DIR}/events.json oc --insecure-skip-tls-verify --request-timeout=5s get events --all-namespaces -o json
queue ${ARTIFACT_DIR}/kubeapiserver.json oc --insecure-skip-tls-verify --request-timeout=5s get kubeapiserver -o json
queue ${ARTIFACT_DIR}/kubecontrollermanager.json oc --insecure-skip-tls-verify --request-timeout=5s get kubecontrollermanager -o json
queue ${ARTIFACT_DIR}/machineconfigpools.json oc --insecure-skip-tls-verify --request-timeout=5s get machineconfigpools -o json
queue ${ARTIFACT_DIR}/machineconfigs.json oc --insecure-skip-tls-verify --request-timeout=5s get machineconfigs -o json
queue ${ARTIFACT_DIR}/controlplanemachinesets.json oc --insecure-skip-tls-verify --request-timeout=5s get controlplanemachinesets -A -o json
queue ${ARTIFACT_DIR}/machinesets.json oc --insecure-skip-tls-verify --request-timeout=5s get machinesets -A -o json
queue ${ARTIFACT_DIR}/machines.json oc --insecure-skip-tls-verify --request-timeout=5s get machines -A -o json
queue ${ARTIFACT_DIR}/namespaces.json oc --insecure-skip-tls-verify --request-timeout=5s get namespaces -o json
queue ${ARTIFACT_DIR}/nodes.json oc --insecure-skip-tls-verify --request-timeout=5s get nodes -o json
queue ${ARTIFACT_DIR}/openshiftapiserver.json oc --insecure-skip-tls-verify --request-timeout=5s get openshiftapiserver -o json
queue ${ARTIFACT_DIR}/persistentvolumes.json oc --insecure-skip-tls-verify --request-timeout=5s get persistentvolumes --all-namespaces -o json
queue ${ARTIFACT_DIR}/persistentvolumeclaims.json oc --insecure-skip-tls-verify --request-timeout=5s get persistentvolumeclaims --all-namespaces -o json
FILTER=gzip queue ${ARTIFACT_DIR}/replicasets.json.gz oc --insecure-skip-tls-verify --request-timeout=5s get replicasets --all-namespaces -o json
queue ${ARTIFACT_DIR}/rolebindings.json oc --insecure-skip-tls-verify --request-timeout=5s get rolebindings --all-namespaces -o json
queue ${ARTIFACT_DIR}/roles.json oc --insecure-skip-tls-verify --request-timeout=5s get roles --all-namespaces -o json
queue ${ARTIFACT_DIR}/services.json oc --insecure-skip-tls-verify --request-timeout=5s get services --all-namespaces -o json
FILTER=gzip queue ${ARTIFACT_DIR}/statefulsets.json.gz oc --insecure-skip-tls-verify --request-timeout=5s get statefulsets --all-namespaces -o json
queue ${ARTIFACT_DIR}/routes.json oc --insecure-skip-tls-verify --request-timeout=5s get routes --all-namespaces -o json
queue ${ARTIFACT_DIR}/subscriptions.json oc --insecure-skip-tls-verify --request-timeout=5s get subscriptions --all-namespaces -o json
queue ${ARTIFACT_DIR}/clusterserviceversions.json oc --insecure-skip-tls-verify --request-timeout=5s get clusterserviceversions --all-namespaces -o json
queue ${ARTIFACT_DIR}/releaseinfo.json oc --insecure-skip-tls-verify --request-timeout=5s adm release info -o json
queue ${ARTIFACT_DIR}/clusterrolebindings.json oc --insecure-skip-tls-verify --request-timeout=5s get clusterrolebindings --all-namespaces -o json

# ArgoCD resources
queue ${ARTIFACT_DIR}/applications_argoproj.json  oc --insecure-skip-tls-verify --request-timeout=5s get applications.argoproj.io --all-namespaces -o json
queue ${ARTIFACT_DIR}/applicationsets.json  oc --insecure-skip-tls-verify --request-timeout=5s get applicationsets.argoproj.io --all-namespaces -o json
queue ${ARTIFACT_DIR}/appprojects.json  oc --insecure-skip-tls-verify --request-timeout=5s get appprojects.argoproj.io --all-namespaces -o json
queue ${ARTIFACT_DIR}/argocds.json  oc --insecure-skip-tls-verify --request-timeout=5s get argocds.argoproj.io --all-namespaces -o json

# Tekton resources
queue ${ARTIFACT_DIR}/repositories.json  oc --insecure-skip-tls-verify --request-timeout=5s get repositories.pipelinesascode.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/pipelines.json  oc --insecure-skip-tls-verify --request-timeout=5s get pipelines.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/eventlisteners.json  oc --insecure-skip-tls-verify --request-timeout=5s get eventlisteners.triggers.tekton.dev --all-namespaces -o json
queue ${ARTIFACT_DIR}/triggerbindings.json  oc --insecure-skip-tls-verify --request-timeout=5s get triggerbindings.triggers.tekton.dev --all-namespaces -o json

# Appstudio resources
queue ${ARTIFACT_DIR}/applications_appstudio.json  oc --insecure-skip-tls-verify --request-timeout=5s get applications.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/buildpipelineselectors.json  oc --insecure-skip-tls-verify --request-timeout=5s get buildpipelineselectors.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/componentdetectionqueries.json  oc --insecure-skip-tls-verify --request-timeout=5s get componentdetectionqueries.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/components.json  oc --insecure-skip-tls-verify --request-timeout=5s get components.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/deploymenttargetclaims.json  oc --insecure-skip-tls-verify --request-timeout=5s get deploymenttargetclaims.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/deploymenttargetclasses.json  oc --insecure-skip-tls-verify --request-timeout=5s get deploymenttargetclasses.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/deploymenttargets.json  oc --insecure-skip-tls-verify --request-timeout=5s get deploymenttargets.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/enterprisecontractpolicies.json  oc --insecure-skip-tls-verify --request-timeout=5s get enterprisecontractpolicies.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/environments.json  oc --insecure-skip-tls-verify --request-timeout=5s get environments.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/integrationtestscenarios.json  oc --insecure-skip-tls-verify --request-timeout=5s get integrationtestscenarios.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/internalrequests.json  oc --insecure-skip-tls-verify --request-timeout=5s get internalrequests.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/promotionruns.json  oc --insecure-skip-tls-verify --request-timeout=5s get promotionruns.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/releaseplanadmissions.json  oc --insecure-skip-tls-verify --request-timeout=5s get releaseplanadmissions.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/releaseplans.json  oc --insecure-skip-tls-verify --request-timeout=5s get releaseplans.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/releases.json  oc --insecure-skip-tls-verify --request-timeout=5s get releases.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/releasestrategies.json  oc --insecure-skip-tls-verify --request-timeout=5s get releasestrategies.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/snapshotenvironmentbindings.json  oc --insecure-skip-tls-verify --request-timeout=5s get snapshotenvironmentbindings.appstudio.redhat.com --all-namespaces -o json
queue ${ARTIFACT_DIR}/snapshots.json  oc --insecure-skip-tls-verify --request-timeout=5s get snapshots.appstudio.redhat.com --all-namespaces -o json

FILTER=gzip queue ${ARTIFACT_DIR}/openapi.json.gz oc --insecure-skip-tls-verify --request-timeout=5s get --raw /openapi/v2

while IFS= read -r i; do
  file="$( echo "$i" | cut -d ' ' -f 2,3,5 | tr -s ' ' '_' )"
  FILTER=gzip queue ${ARTIFACT_DIR}/pods/${file}.log.gz oc --insecure-skip-tls-verify logs --request-timeout=20s $i
  FILTER=gzip queue ${ARTIFACT_DIR}/pods/${file}_previous.log.gz oc --insecure-skip-tls-verify logs --request-timeout=20s -p $i
done < /tmp/containers
