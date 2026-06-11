#!/usr/bin/env sh

RESTART=true
SECRETS_MOUNT_POINT=/mnt/secrets

if [ ! -d ${SECRETS_MOUNT_POINT} ]; then
    echo "${SECRETS_MOUNT_POINT} does not exist or is not a directory"
    exit 0
fi

SECRETS_SUM=$(cat $(find ${SECRETS_MOUNT_POINT} -type f | sort) | sha1sum | awk '{print $1}')
echo "Secret sum: ${SECRETS_SUM}"

NAMESPACE=$(cat /run/secrets/kubernetes.io/serviceaccount/namespace)
TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)

OLD_SECRETS_SUM=$(curl https://${KUBERNETES_SERVICE_HOST}:443/api/v1/namespaces/${NAMESPACE}/configmaps/${BEACON_NAME} --header "Authorization: Bearer ${TOKEN}" --insecure --silent | jq -r ".data.secrets_sum")

echo "Old secret sum: ${OLD_SECRETS_SUM}"

if [[ ! ${OLD_SECRETS_SUM} ]]; then RESTART=false; fi

if [[ "${OLD_SECRETS_SUM}" != "${SECRETS_SUM}" ]]; then
    curl https://${KUBERNETES_SERVICE_HOST}:443/api/v1/namespaces/${NAMESPACE}/configmaps/${BEACON_NAME} \
        --data "{\"data\":{\"secrets_sum\":\"${SECRETS_SUM}\"}}" \
        --header "Authorization: Bearer ${TOKEN}" --header "content-type: application/merge-patch+json" \
        --insecure --request PATCH
    if [[ ${RESTART} = true ]]; then
        echo "Deleted pods:"
        curl https://${KUBERNETES_SERVICE_HOST}:443/api/v1/namespaces/${NAMESPACE}/pods \
            --data-urlencode "labelSelector=release=${RELEASE_NAME},run in (${RELEASE_NAME}-dbserver,${RELEASE_NAME}-odm-decisioncenter,${RELEASE_NAME}-odm-decisionrunner,${RELEASE_NAME}-odm-decisionserverconsole,${RELEASE_NAME}-odm-decisionserverruntime)" \
            --get --header "Authorization: Bearer ${TOKEN}" --insecure --request DELETE --silent | jq -r '.items[].metadata.name'
        # https://stackoverflow.com/questions/296536/how-to-urlencode-data-for-curl-command
    fi
fi

exit 0
