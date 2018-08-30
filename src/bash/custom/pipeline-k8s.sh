function deployService() {
	local serviceName
	serviceName="${1}"
	local serviceType
	serviceType="$(toLowerCase "${2}")"
	local serviceCoordinates
	serviceCoordinates="$(if [[ "${3}" == "null" ]]; then
		echo "";
	else
		echo "${3}";
	fi)"
	local coordinatesSeparator=":"
	echo "Will deploy service with type [${serviceType}] name [${serviceName}] and coordinates [${serviceCoordinates}]"
	case ${serviceType} in
		rabbitmq)
			deployRabbitMq "${serviceName}"
		;;
		mysql)
			deployMySql "${serviceName}"
		;;
		eureka)
			local previousIfs
			previousIfs="${IFS}"
			IFS=${coordinatesSeparator} read -r EUREKA_ARTIFACT_ID EUREKA_VERSION <<<"${serviceCoordinates}"
			IFS="${previousIfs}"
			deployEureka "${EUREKA_ARTIFACT_ID}:${EUREKA_VERSION}" "${serviceName}"
		;;
		infrastructure)
			local previousIfs
			previousIfs="${IFS}"
			IFS=${coordinatesSeparator} read -r INFRASTRUCTURE_ARTIFACT_ID INFRASTRUCTURE_VERSION <<<"${serviceCoordinates}"
			IFS="${previousIfs}"
			deployInfrastructure "${INFRASTRUCTURE_ARTIFACT_ID}:$INFRASTRUCTURE_VERSION" "${serviceName}"
		;;		
		stubrunner)
			local uniqueEurekaName
			uniqueEurekaName="$(eurekaName)"
			local uniqueRabbitName
			uniqueRabbitName="$(rabbitMqName)"
			local previousIfs
			previousIfs="${IFS}"
			IFS=${coordinatesSeparator} read -r STUBRUNNER_ARTIFACT_ID STUBRUNNER_VERSION <<<"${serviceCoordinates}"
			IFS="${previousIfs}"
			local parsedStubRunnerUseClasspath
			parsedStubRunnerUseClasspath="$(echo "${PARSED_YAML}" | jq --arg x "${LOWERCASE_ENV}" '.[$x].services[] | select(.type == "stubrunner") | .useClasspath' | sed 's/^"\(.*\)"$/\1/')"
			local stubRunnerUseClasspath
			stubRunnerUseClasspath=$(if [[ "${parsedStubRunnerUseClasspath}" == "null" ]]; then
				echo "false";
			else
				echo "${parsedStubRunnerUseClasspath}";
			fi)
			deployStubRunnerBoot "${STUBRUNNER_ARTIFACT_ID}:${STUBRUNNER_VERSION}" "${REPO_WITH_BINARIES_FOR_UPLOAD}" "${uniqueRabbitName}" "${uniqueEurekaName}" "${serviceName}"
		;;
		*)
			echo "Unknown service [${serviceType}]"
			return 1
		;;
	esac
}

function deployInfrastructure() {
	local imageName="${1}"
	local appName="${2}"
	local objectDeployed

	local customScriptRoot="${__ROOT}/${CUSTOM_SCRIPT_IDENTIFIER}"
	local customScriptDir=${CUSTOM_SCRIPT_DIR:-${customScriptRoot:-}}

	local podName="${appName}.yml"
	local serviceName="${appName}-service.yml"

	objectDeployed="$(objectDeployed "service" "${appName}")"
	if [[ "${ENVIRONMENT}" == "STAGE" && "${objectDeployed}" == "true" ]]; then
		echo "Service [${appName}] already deployed. Won't redeploy for stage"
		return
	fi
	echo "Deploying Infrastructure. Options - image name [${imageName}], app name [${appName}], env [${ENVIRONMENT}]"
	local originalDeploymentFile="${customScriptDir}/k8s/${podName}"
	local originalServiceFile="${customScriptDir}/k8s/${serviceName}"
	local outputDirectory
	outputDirectory="$(outputFolder)/k8s"
	mkdir -p "${outputDirectory}"
	cp "${originalDeploymentFile}" "${outputDirectory}"
	cp "${originalServiceFile}" "${outputDirectory}"
	local deploymentFile="${outputDirectory}/${podName}"
	echo "Deployment file: ${deploymentFile}"
	local serviceFile="${outputDirectory}/${serviceName}"
	echo "Service file: ${serviceFile}"
	substituteVariables "appName" "${appName}" "${deploymentFile}"
	substituteVariables "appUrl" "${appName}.${PAAS_NAMESPACE}" "${deploymentFile}"
	substituteVariables "imgName" "${imageName}" "${deploymentFile}"
	substituteVariables "appName" "${appName}" "${serviceFile}"
	if [[ "${ENVIRONMENT}" == "TEST" ]]; then
		deleteAppByFile "${deploymentFile}"
		deleteAppByFile "${serviceFile}"
	fi
	replaceApp "${deploymentFile}"
	replaceApp "${serviceFile}"
	waitForAppToStart "${appName}"
}