#!/bin/bash

# The script will clone the infra repos and build their docker images
# You can provide a destination directory to which project should be cloned.
# If not provided will use a temporary directory.
#
# Examples:
#   $ ./tools/deploy-infra.sh
#   $ ./tools/deploy-infra.sh ../repos/pivotal/
#

set -o errexit

if [[ $# -lt 1 ]]; then
	DEST_DIR="$( mktemp -d )"
else
	DEST_DIR="$1"
fi

POTENTIAL_DOCKER_HOST="$( echo "$DOCKER_HOST" | cut -d ":" -f 2 | cut -d "/" -f 3 )"
if [[ -z "${POTENTIAL_DOCKER_HOST}" ]]; then
    POTENTIAL_DOCKER_HOST="localhost"
fi

function deploy_project {
	local project_repo="$1"
	local project_name

	project_name="$( basename "${project_repo}" )"

	echo "Deploying ${project_name} to Docker registry"

	pushd "${DEST_DIR}"
	rm -rf "${project_name}"
	git clone "${project_repo}" "${project_name}" && cd "${project_name}"
	./mvnw install package docker:build -Pdocker -DpushImage
	popd
}

echo "Using Docker running at [${POTENTIAL_DOCKER_HOST}]"
echo "Destination directory to clone the apps is [${DEST_DIR}]"
echo "Artifactory ID [${ARTIFACTORY_ID}]"

#deploy_project "https://github.com/davsuapas/DanceSchool-Eureka"
#deploy_project "https://github.com/davsuapas/DanceSchool-Configuration"
#deploy_project "https://github.com/davsuapas/DanceSchool-Zuul"
#deploy_project "https://github.com/davsuapas/DanceSchool-HystrixDashboard"
deploy_project "https://github.com/davsuapas/DanceSchool-TurbineStream"


echo "DONE!"
