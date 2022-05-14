#!/bin/bash

# All intermediate functions are defined in utils.sh
source litmus/utils.sh

namespace=${AGENT_NAMESPACE}
installation_mode=${INSTALLATION_MODE}
accessPoint=${ACCESS_URL}
agentName=${AGENT_NAME}
projectName=${PROJECT_NAME}

components="subscriber,chaos-exporter,chaos-operator-ce,event-tracker,workflow-controller"

function configure_account(){
    litmusctl config set-account --endpoint="${accessPoint}" --username="admin" --password="litmus"
}

function test_install_with_nodeSelectors() {
    configure_account
    
    projectID=$(litmusctl get projects | grep "${projectName}" |  awk '{print $1}')

    kubectl create ns ${namespace}
    # Installing CRD's, required for namespaced mode
    kubectl apply -f https://raw.githubusercontent.com/litmuschaos/litmus/master/litmus-portal/litmus-portal-crds.yml
    
    litmusctl create agent --agent-name=${namespace} --project-id=${projectID} --installation-mode=namespace --namespace=${namespace} --node-selector="beta.kubernetes.io/arch=arm64" --non-interactive

    wait_for_agent_to_be_ready

    echo "Verifying nodeSelectors in all required Deployments"

    for i in $(echo $components | sed "s/,/ /g")
    do
        verify_deployment_nodeselector ${i} ${namespace} '{"beta.kubernetes.io/arch":"arm64"}' 
    done
}

function wait_for_agent_to_be_ready(){

    echo -e "\n---------------Pods running in ${namespace} Namespace---------------\n"
    kubectl get pods -n ${namespace}

    echo -e "\n---------------Waiting for all pods to be ready---------------\n"
    # Waiting for pods to be ready (timeout - 360s)
    wait_for_pods ${namespace} 360

    # Deployments verification
    verify_all_components $components ${namespace}
}

test_install_with_nodeSelectors