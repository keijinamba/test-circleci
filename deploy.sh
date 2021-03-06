#!/usr/bin/env bash

# valiabls
AWS_DEFAULT_REGION=ap-northeast-1
AWS_ECS_TASKDEF_NAME=test-nginx-task
AWS_ECS_CLUSTER_NAME=test-nginx-cluster
AWS_ECS_SERVICE_NAME=test-nginx-service
AWS_ECR_REP_NAME=test-nginx

# Create Task Definition
make_task_def(){
	task_template='[
		{
			"name": "%s",
			"image": "%s.dkr.ecr.%s.amazonaws.com/%s:%s",
			"essential": true,
			"memory": 200,
			"cpu": 10,
			"portMappings": [
				{
					"containerPort": 80,
					"hostPort": 80
				}
			]
		}
	]'

	task_def=$(printf "$task_template" ${AWS_ECS_TASKDEF_NAME} $AWS_ACCOUNT_ID ${AWS_DEFAULT_REGION} ${AWS_ECR_REP_NAME} $CIRCLE_SHA1)
}

# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"

configure_aws_cli(){
	aws --version
	aws configure set default.region ${AWS_DEFAULT_REGION}
	aws configure set default.output json
}

deploy_cluster() {

    make_task_def
    register_definition
    if [ $(aws ecs update-service --cluster ${AWS_ECS_CLUSTER_NAME} --service ${AWS_ECS_SERVICE_NAME} --task-definition $revision | \
                   $JQ '.service.taskDefinition') != $revision ]; then
        echo "Error updating service."
        return 1
    fi
}


push_ecr_image(){
	eval $(aws ecr get-login --region ${AWS_DEFAULT_REGION})
	docker push $AWS_ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/${AWS_ECR_REP_NAME}:$CIRCLE_SHA1
}

register_definition() {

    if revision=$(aws ecs register-task-definition --container-definitions "$task_def" --family ${AWS_ECS_TASKDEF_NAME} | $JQ '.taskDefinition.taskDefinitionArn'); then
        echo "Revision: $revision"
    else
        echo "Failed to register task definition"
        return 1
    fi

}

echo "--------- call configure_aws_cli ---------"
configure_aws_cli
echo "--------- call push_ecr_image ---------"
push_ecr_image
echo "--------- call deploy_cluster ---------"
deploy_cluster