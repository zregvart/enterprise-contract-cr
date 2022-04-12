# Demo

This repository contains the demo of the Enterprise Contract Custom Resource.
To launch the demo run `demo.sh` script. The script assumes that you're
logged in to a Kubernetes cluster as an administrator to be able to create
objects in cluster scope, and that Tekton is installed.

Within the `policies` directory there are two stub policies that are pushed
to the image repository specified in the `policies/Makefile` via `TAG_PREFIX`.

Configuration of the demo is driven by the `EnterpriseContract` custom resource
sourced from `enterprise-contract-sample.yml` file.

# How does this work

The demo runs HACBS Test workstream `sanity-label-check` task, which is
modified to include the latest policies via a custom built image from
[hacbs-test](https://github.com/redhat-appstudio/hacbs-test) as the
[quay.io/redhat-appstudio/hacbs-test](https://quay.io/repository/redhat-appstudio/hacbs-test)
image has not been updated with the latest policies at the time of creating
the demo.
The output of the `sanity-label-check` task is captured and the non-JSON
content is filtered out and stored in the `hacbs-test-output` ConfigMap.
This is how the test output will be passed to the Enterprise Contract task.
The Enterprise Contract task, defined in `ec-task.yml` takes that output
mounted as a volume, a Golang Template also stored in the ConfigMap and mounted
as a volume to produce the script that will be run.
The script defined via `contract-script.tmpl` loops through all referenced
policies from the `sample` `EnterpriseContract` custom resource and uses
`oc image extract` to copy the files out of the images to
`${WORKDIR}/policies/${POLICYDIR}`. The `${WORKDIR}/config/suppressions.json`
JSON file is built containing the suppressed names of HACBS tests whose failures
should be ignored.
Lastly `opa` is invoked with the all policy directories, test data directory
and the configuration directory and the output is pretty printed.
