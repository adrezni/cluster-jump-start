#!/bin/bash

TMP_DIR=scratch

DEFAULT_USER=${WORKSHOP_USER:-user}
DEFAULT_PASS=${WORKSHOP_PASS:-openshift}
WORKSHOP_NUM=${WORKSHOP_NUM:-25}
# GROUP_ADMINS=workshop-admins

OBJ_DIR=${TMP_DIR}/workshop
DEFAULT_HTPASSWD=${OBJ_DIR}/htpasswd-workshop

# shellcheck disable=SC2120
genpass(){
  < /dev/urandom LC_ALL=C tr -dc _A-Z-a-z-0-9 | head -c "${1:-32}"
}

htpasswd_add_user(){
  USER=${1:-admin}
  PASS=${2:-$(genpass)}
  HTPASSWD_FILE=${3:-${DEFAULT_HTPASSWD}}

  echo "
    USERNAME: ${USER}
    PASSWORD: ${PASS}

    FILENAME:  ${HTPASSWD_FILE}
    PASSWORDS: ${HTPASSWD_FILE}.txt
  "

  touch "${HTPASSWD_FILE}" "${HTPASSWD_FILE}".txt
  sed -i '/# '"${USER}"'/d' "${HTPASSWD_FILE}".txt
  echo "# ${USER} - ${PASS}" >> "${HTPASSWD_FILE}.txt"

  if which htpasswd >/dev/null 2>&1; then
    echo "using local htpasswd..."
    htpasswd -b -B -C10 "${HTPASSWD_FILE}" "${USER}" "${PASS}"
  else
    echo "using oc to run pod..."
    oc run \
      --image httpd \
      -q --rm -i minion -- /bin/sh -c 'sleep 2; htpasswd -n -b -B -C10 '"${USER}"' '"${PASS}"'' > "${HTPASSWD_FILE}" 2>/dev/null
  fi
}

htpasswd_ocp_get_file(){
  HTPASSWD_FILE=${1:-${DEFAULT_HTPASSWD}}
  HTPASSWD_NAME=$(basename "${HTPASSWD_FILE}")

  oc -n openshift-config \
    get secret/"${HTPASSWD_NAME}" > /dev/null 2>&1 || return 1

  oc -n openshift-config \
    extract secret/"${HTPASSWD_NAME}" \
    --keys=htpasswd \
    --to=- > "${HTPASSWD_FILE}" 2>/dev/null
}

htpasswd_ocp_set_file(){
  HTPASSWD_FILE=${1:-${DEFAULT_HTPASSWD}}
  HTPASSWD_NAME=$(basename "${HTPASSWD_FILE}")

  touch "${HTPASSWD_FILE}" || return 1

  oc -n openshift-config \
    set data secret/"${HTPASSWD_NAME}" \
    --from-file=htpasswd="${HTPASSWD_FILE}"
}

workshop_init(){

  # do not delete empty
  [ "${OBJ_DIR:?}" = "" ] && return
  
  rm -rf "${OBJ_DIR}"
  mkdir -p "${OBJ_DIR}"
}

workshop_create_admin(){
  # get htpasswd file
  htpasswd_ocp_get_file "${HTPASSWD_FILE}"

  # setup admin user
  htpasswd_add_user admin "$(genpass)" "${HTPASSWD_FILE}"
  htpasswd_ocp_set_file "${HTPASSWD_FILE}"

  # oc adm groups add-users rhods-admins admin
}

workshop_create_users(){
  USER0=${1:-user0}
  TOTAL=${2:-25}
  LIST=$(eval echo "{0..${TOTAL}}")

  if [ -d "${USER0}" ]; then
    echo "Found: user template ${USER0}"
  else
    echo "Error: provide a path to user0 template
      example:
        workshop_create_users < path to template >
    "
    return 1
  fi

  # setup workshop users
  # shellcheck disable=SC2068
  for num in ${LIST[@]}
  do
    # create login hashes
    htpasswd_add_user "${DEFAULT_USER}${num}" "${DEFAULT_PASS}${num}" "${HTPASSWD_FILE}"
    # workshop_add_user_to_group "${DEFAULT_USER}${num}" "${DEFAULT_GROUP}"

    # create user project from template
    cp -a "${USER0}" "${OBJ_DIR}/${DEFAULT_USER}${num}"
    sed -i 's/user0/'"${DEFAULT_USER}${num}"'/g' "${OBJ_DIR}/${DEFAULT_USER}${num}/"*.yaml
    sed -i 's@- ../../components@- ../../../components@g' "${OBJ_DIR}/${DEFAULT_USER}${num}/"kustomization.yaml

    echo "Creating: ${DEFAULT_USER}${num}"
    oc apply -k "${OBJ_DIR}/${DEFAULT_USER}${num}"
  done

  # update htpasswd in cluster
  htpasswd_ocp_set_file "${HTPASSWD_FILE}"

}

workshop_load_test(){
  TOTAL=${1:-25}
  LIST=$(eval echo "{0..${TOTAL}}")

  # setup workshop users
  # shellcheck disable=SC2068
  for num in ${LIST[@]}
  do
    echo "Creating: ${DEFAULT_USER}${num}"
    oc -n "${DEFAULT_USER}${num}" \
      create -f components/pipelines/manifests/pipeline-run.yaml
  done

  # update htpasswd in cluster
  htpasswd_ocp_set_file "${HTPASSWD_FILE}"
}

setup_user_auth(){

  # Get the current OAuth configuration
  OAUTH_CONFIG=$(oc get oauth cluster -o json)

  # Check if htpasswd provider already exists
  if echo "$OAUTH_CONFIG" | grep -q '"name": "htpasswd"'; then
    echo "htpasswd identity provider already exists in the OAuth configuration."
    exit 0
  fi

  # Add htpasswd provider to the current configuration
  UPDATED_OAUTH_CONFIG=$(echo "$OAUTH_CONFIG" | jq '.spec.identityProviders += [{
      "name": "htpasswd",
      "mappingMethod": "claim",
      "type": "HTPasswd",
      "htpasswd": {
          "fileData": {
              "name": "'"$SECRET_NAME"'"
          }
      }
  }]')

  # Apply the updated OAuth configuration
  echo "$UPDATED_OAUTH_CONFIG" | oc apply -f -

  # Verify the OAuth configuration was updated
  oc get oauth cluster -o json | jq '.spec.identityProviders'

}

workshop_clean(){
  oc delete project -l owner=workshop
}

workshop_init