package io.cloudpipelines.steps

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.Job
import javaposse.jobdsl.dsl.helpers.ScmContext
import javaposse.jobdsl.dsl.helpers.publisher.PublisherContext
import javaposse.jobdsl.dsl.helpers.step.StepContext
import javaposse.jobdsl.dsl.helpers.wrapper.WrapperContext
import javaposse.jobdsl.dsl.jobs.FreeStyleJob

import io.cloudpipelines.common.BashFunctions
import io.cloudpipelines.common.Coordinates
import io.cloudpipelines.common.EnvironmentVariables
import io.cloudpipelines.common.PipelineDefaults
import io.cloudpipelines.common.PipelineDescriptor
import io.cloudpipelines.common.StepEnabledChecker

/**
 * Tests on stage
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class StageTest implements Step<FreeStyleJob> {
	private final DslFactory dsl
	private final io.cloudpipelines.common.PipelineDefaults pipelineDefaults
	private final BashFunctions bashFunctions
	private final CommonSteps commonSteps

	StageTest(DslFactory dsl, io.cloudpipelines.common.PipelineDefaults pipelineDefaults) {
		this.dsl = dsl
		this.pipelineDefaults = pipelineDefaults
		this.bashFunctions = pipelineDefaults.bashFunctions()
		this.commonSteps = new CommonSteps(this.pipelineDefaults, this.bashFunctions)
	}

	@Override
	CreatedJob step(String projectName, Coordinates coordinates, PipelineDescriptor descriptor) {
		StepEnabledChecker checker = new StepEnabledChecker(descriptor, pipelineDefaults)
		if (checker.stageStepMissing()) {
			return null
		}
		String gitRepoName = coordinates.gitRepoName
		String fullGitRepo = coordinates.fullGitRepo
		Job job = dsl.job("${projectName}-stage-env-test") {
			deliveryPipelineConfiguration('Stage', 'Tests on stage')
			environmentVariables(pipelineDefaults.defaultEnvVars as Map<Object, Object>)
			wrappers {
				commonSteps.defaultWrappers(delegate as WrapperContext)
				commonSteps.deliveryPipelineVersion(delegate as WrapperContext)
				credentialsBinding {
					// remove::start[CF]
					if (pipelineDefaults.cfStageCredentialId()) usernamePassword(
						EnvironmentVariables.PAAS_STAGE_USERNAME_ENV_VAR,
						EnvironmentVariables.PAAS_STAGE_PASSWORD_ENV_VAR,
						pipelineDefaults.cfStageCredentialId())
					// remove::end[CF]
					// remove::start[K8S]
					if (pipelineDefaults.k8sStageTokenCredentialId()) string(
						EnvironmentVariables.TOKEN_ENV_VAR,
						pipelineDefaults.k8sStageTokenCredentialId())
					// remove::end[K8S]
				}
			}
			scm {
				commonSteps.configureScm(delegate as ScmContext, fullGitRepo, "dev/${gitRepoName}/\${${EnvironmentVariables.PIPELINE_VERSION_ENV_VAR}}")
			}
			steps {
				commonSteps.downloadTools(delegate as StepContext, fullGitRepo)
				commonSteps.runStep(delegate as StepContext, "stage_e2e.sh")
			}
			publishers {
				commonSteps.defaultPublishers(delegate as PublisherContext)
			}
		}
		customize(job)
		return new CreatedJob(job, autoNextJob(checker))
	}

	private boolean autoNextJob(StepEnabledChecker checker) {
		return checker.autoProdSet()
	}

	@Override void customize(FreeStyleJob job) {
		commonSteps.customizers().each {
			it.customizeAll(job)
			it.customizeStage(job)
		}
	}
}
