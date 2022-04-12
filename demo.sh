#!/usr/bin/env bash

set -euo pipefail

# --- SETUP ---
GIT_HASH=$(git ls-remote --heads https://github.com/redhat-appstudio/build-definitions.git refs/heads/main|cut -f 1)
APPSTUDIO_UTILS_IMGREF=quay.io/redhat-appstudio/appstudio-utils:${GIT_HASH}
HACBS_TEST_POLICY_IMGREF=quay.io/zregvart_redhat/hacbs-test:be7e6125aec152685668f1b061f361a7cac7a92a
TEST_IMGREF=quay.io/cvpops/test-index:ovp-test

# Custom Resource Definition
kubectl apply -f enterprise-contract-crd.yml
# Example policy for the demo
kubectl apply -f enterprise-contract-sample.yml
# Allow the pipeline Service Account to access ^
kubectl apply -f enterprise-contract-rbac.yml
# Create the Go Template file used in the ec-task, this should be baked into the ec-task's image
kubectl create configmap ec-kubectl-template --from-file=contract-script.tmpl --dry-run=client --output yaml| kubectl apply -f -

# --- DEMO ---

# Run HACBS Test task
# Pull the HACBS Tests sanity-label-check task but change the policy image to newer version
HACBS_TEST_TASK_FILE=$(mktemp XXXXXXXXXX.yml)
CLEANUP_FILES=("${HACBS_TEST_TASK_FILE}")
function cleanup {
  rm "${CLEANUP_FILES[@]}"
}
trap cleanup EXIT
yq e ".spec.steps[1].image = \"${HACBS_TEST_POLICY_IMGREF}\" | .spec.params[0].type = \"string\""  <(curl -s https://raw.githubusercontent.com/redhat-appstudio/build-definitions/main/tasks/sanity-label-check.yaml) > "${HACBS_TEST_TASK_FILE}"
# Run the HACBS Test task
HACBS_TEST_TASK=$(tkn task start --filename "${HACBS_TEST_TASK_FILE}" --param sourceImage="${TEST_IMGREF}" --output JSON | jq -r .metadata.name)
tkn taskrun logs --follow "${HACBS_TEST_TASK}"
# Pull the JSON output from stdout
HACBS_TEST_OUTPUT=$(tkn taskrun logs --prefix=false "${HACBS_TEST_TASK}" 2>/dev/null | sed -n '/^\[$/,/^\]$/p')
kubectl create configmap hacbs-test-output --from-file=test.json=<(echo "${HACBS_TEST_OUTPUT}" | jq '.[0]') --dry-run=client --output yaml| kubectl apply -f -

# Run HACBS EC task
HACBS_EC_TASK_FILE=$(mktemp XXXXXXXXXX.yml)
CLEANUP_FILES+=("${HACBS_EC_TASK_FILE}")
sed "s#\\\${APPSTUDIO_UTILS_IMGREF}#${APPSTUDIO_UTILS_IMGREF}#" ec-task.yml > "${HACBS_EC_TASK_FILE}"
tkn task start --filename "${HACBS_EC_TASK_FILE}" --param POLICY_NAME=sample --showlog
