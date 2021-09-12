#!/bin/bash

# Build and deploy the API docs for PSL.
# The docs are only deployed for tag pushes.

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly REPO_ROOT_DIR="${THIS_DIR}/.."
readonly DOCS_DIR="${REPO_ROOT_DIR}/target/site/apidocs"
readonly TEMP_DIR='/tmp/psl-docs-deploy'

readonly WEBSITE_REPO_URL="https://linqs-deploy:${LINQS_DEPLOY_TOKEN}@github.com/linqs/psl-website.git"

readonly REF_VERSION_TAG_REGEX='^refs/tags/(CANARY-)?[0-9]+\.[0-9]+\.[0-9]+$'
readonly API_DIR='api'

readonly GIT_USER_EMAIL='linqs.deploy@gmail.com'
readonly GIT_USER_NAME='LINQS Deploy'

function buildDocs() {
    echo "Building docs."

    pushd . > /dev/null
    cd "${REPO_ROOT_DIR}"
        mvn javadoc:aggregate -P all-modules
    popd > /dev/null
}

function deployDocs() {
    local tag=$(echo "${GITHUB_REF}" | sed 's#refs/tags/##')

    echo "Deploying docs (${tag})."

    rm -Rf "${TEMP_DIR}"
    mkdir -p "${TEMP_DIR}"

    pushd . > /dev/null
    cd "${TEMP_DIR}"
        git clone "${WEBSITE_REPO_URL}"
        cd psl-website

        mkdir -p "${API_DIR}"
        cp -r "${DOCS_DIR}" "${API_DIR}/${tag}"

        _scripts/update-versions.py

        git add .
        git -c user.email="${GIT_USER_EMAIL}" -c user.name="${GIT_USER_NAME}" commit -m "Added autogenerated api docs from CI (${tag})."
        git push
    popd > /dev/null
}

function main() {
    if [[ $# -ne 0 ]]; then
        echo "USAGE: $0"
        echo "   LINQS_DEPLOY_TOKEN and GITHUB_REF must be supplied as env variables."
        exit 1
    fi

    trap exit SIGINT
    set -e

    # Bail if no deploy keys exist.
    if [[ -z "${LINQS_DEPLOY_TOKEN}" ]]; then
        echo "Skipping docs deploy, cannot find token."
        return
    fi

    # Bail if no ref.
    if [[ -z "${GITHUB_REF}" ]]; then
        echo "Skipping docs deploy, cannot find git ref."
        return
    fi

    # Only match refs that look like version tags.
    if [[ ! "${GITHUB_REF}" =~ $REF_VERSION_TAG_REGEX ]]; then
        echo "Skipping docs deploy, only deploy on version tags. Current ref: '${GITHUB_REF}'."
        return
    fi

    buildDocs
    deployDocs
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
