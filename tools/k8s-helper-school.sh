function usage {
	echo "usage: $0: <setup-prod-infra>"
	exit 1
}

function copyK8sYamls() {
	mkdir -p "${FOLDER}build"
	cp "${SCRIPTS}"/src/main/bash/k8s/*.* "${FOLDER}build/"
}

function system {
	unameOut="$(uname -s)"
	case "${unameOut}" in
		Linux*)	 machine=linux;;
		Darwin*)	machine=darwin;;
		*)		  echo "Unsupported system" && exit 1
	esac
	echo ${machine}
}

SYSTEM=$( system )

[[ $# -eq 1 ]] || usage

export ROOT_FOLDER
ROOT_FOLDER="$( pwd )/../"
export FOLDER
FOLDER="$( pwd )/"
if [ -d "tools" ]; then
	FOLDER="$( pwd )/tools/"
	ROOT_FOLDER="$( pwd )/"
fi

SCRIPTS_FETCH_LOCAL="true"

export KUBE_CONFIG_PATH="$HOME/.kube/config"
export PAAS_NAMESPACE="cloudpipelines-prod"
export PAAS_PROD_API_URL="192.168.99.100:8443"
export ENVIRONMENT="PROD"
export PAAS_TYPE="k8s"
export LANGUAGE_TYPE="jvm"
export PROJECT_TYPE="gradle"
export TOOLS_REPO="${TOOLS_REPO:-https://github.com/CloudPipelines/scripts}"
export SCRIPTS

function fetchAndSourceScripts() {

	fetchRemoteOrLocal

	export CUSTOM_SCRIPT_DIR="${SCRIPTS}/custom"

	pushd "${ROOT_FOLDER}tools/k8s"

		# shellcheck source=/dev/null
		source "${SCRIPTS}"/src/main/bash/pipeline-k8s.sh

		# Extract custom scripts
		tar -zxf "${ROOT_FOLDER}build/bash/custom/scripts.tar.gz" -C "${SCRIPTS}"
		# shellcheck source=/dev/null
		source "${SCRIPTS}"/custom/pipeline-k8s.sh

		# Overridden functions
		function outputFolder() {
			echo "${FOLDER}build"
		}
		export -f outputFolder		

		function mySqlDatabase() {
			echo "github"
		}
		export -f mySqlDatabase

		function waitForAppToStart() {
			echo "not waiting for the app to start"
		}
		export -f waitForAppToStart
	popd
}

function fetchRemoteOrLocal() {
	SCRIPTS="$(mktemp -d)"
	trap '{ rm -rf ${tmpDir}; }' EXIT
	if [[ "${SCRIPTS_FETCH_LOCAL}" == "true" ]]; then
		echo "Fetching local: ../scripts to ${SCRIPTS}"
		cp -a ../scripts/. "${SCRIPTS}"  
	else
		echo "Fetching remote: ${TOOLS_REPO}"
		git clone "${TOOLS_REPO}" "${SCRIPTS}"
	fi
}

case $1 in

	setup-prod-infra)
		fetchAndSourceScripts
		copyK8sYamls
		deployService "eureka-school" "eureka" "elipcero/eureka-school:latest"
		deployService "configuration-school" "infrastructure" "elipcero/configuration-school:latest"
		;;

	*)
		usage
		;;
esac
