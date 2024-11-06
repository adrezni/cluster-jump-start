#!/bin/bash

TIMEOUT=60

cd "$(dirname "$0")" && pwd

self_distruct(){
  NAMESPACE=${1:-adhoc-admin}
  [ -z "${NAMESPACE}" ] && return
  echo "
    engaging self cleaning...
    removing project: ${NAMESPACE} in ${TIMEOUT}s
  "
  
  sleep "${TIMEOUT}"
  oc delete project "${NAMESPACE}"
}

k8s_null_finalizers(){
  OBJ=${1}
  [ -z "${OBJ}" ] && return
  NS=${2}
  [ -z "${NS}" ] || ARGS="-n ${NS}"

  # shellcheck disable=SC2086
  kubectl \
    patch "${OBJ}" \
    ${ARGS} \
    --type=merge \
    -p '{"metadata":{"finalizers":null}}'
    # --type="json" \
    # -p '[{"op": "remove", "path":"/metadata/finalizers"}]'

  # shellcheck disable=SC2086
  kubectl delete ${ARGS} "${OBJ}"
}

delete_namespaces(){
  xargs -l oc delete ns < namespaces.txt
}

get_crs(){
  for obj in $(< crds.txt)
  do
    # echo ${obj}
    CR=$(oc get "${obj}" -A -o go-template='{{range .items}}'"${obj}"'/{{.metadata.name}}{{if .metadata.namespace}} {{.metadata.namespace}}{{end}}{{"\n"}}{{end}}')
    [ -n "${CR// }" ] && echo "${CR}"
  done
}

delete_crs(){
  while read -r obj ns
  do
    k8s_null_finalizers "${obj}" "${ns}"
  done < <(get_crs)
}

delete_crds(){
  xargs -l oc delete crd < crds.txt
}

delete_misc(){

  oc -n knative-serving delete knativeservings.operator.knative.dev knative-serving
  oc delete consoleplugin console-plugin-nvidia-gpu

  CSVS=(
    operators.coreos.com/authorino-operator.openshift-operators
    operators.coreos.com/devworkspace-operator.openshift-operators
    operators.coreos.com/gpu-operator-certified.nvidia-gpu-operator
    operators.coreos.com/openshift-pipelines-operator-rh.openshift-operators
    operators.coreos.com/nfd.openshift-nfd
    operators.coreos.com/rhods-operator.redhat-ods-operator
    operators.coreos.com/servicemeshoperator.openshift-operators
    operators.coreos.com/serverless-operator.openshift-serverless
    operators.coreos.com/web-terminal.openshift-operators
    
  )

  # shellcheck disable=SC2068
  for csv in ${CSVS[@]}
  do
    # set csv to cleanup
    oc get csv -A -l "${csv}" -o yaml | \
      sed 's/^    enabled: false/    enabled: true/' | \
        oc apply -f -
    oc delete csv -A -l "${csv}"
  done

  oc delete -n openshift-operators deploy devworkspace-webhook-server

  GPU_MACHINE_SET=$(oc -n openshift-machine-api get machinesets -o name | grep -E -v 'worker')
  for set in ${GPU_MACHINE_SET}
  do
    oc -n openshift-machine-api delete "$set"
  done

  WEBHOOK=$(oc get validatingwebhookconfiguration,mutatingwebhookconfiguration -o name | grep -E 'tekton.dev')
  for set in ${WEBHOOK}
  do
    oc -n openshift-machine-api delete "$set"
  done
}

uninstall_demo(){

  echo "start: uninstall"

  # oc delete --ignore-not-found=true --grace-period="${TIMEOUT}" datasciencecluster default-dsc
  # oc delete --ignore-not-found=true --grace-period="${TIMEOUT}" dscinitialization default-dsci

  # sleep 8

  # oc delete --ignore-not-found=true --grace-period="${TIMEOUT}" -A --all servicemeshcontrolplanes.maistra.io
  # oc delete --ignore-not-found=true --grace-period="${TIMEOUT}" -A --all servicemeshmemberrolls.maistra.io
  # oc delete --ignore-not-found=true --grace-period="${TIMEOUT}" -A --all servicemeshmembers.maistra.io

  delete_crs

  oc delete --ignore-not-found=true --timeout=0s --force -k https://github.com/hemang-rh/openshift-gitops/demo

  delete_misc
  delete_crds
  delete_namespaces

  echo "end: uninstall"
}

uninstall_demo
self_distruct
