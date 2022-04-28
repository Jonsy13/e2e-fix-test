#!/bin/bash

# All intermediate functions are defined in utils.sh
source litmus/utils.sh

litmusctlVersion=${LITMUSCTL_VERSION}
namespace=${AGENT_NAMESPACE}
installation_mode=${INSTALLATION_MODE}
accessPoint=${ACCESS_URL}
setupCLI=${SETUP_CLI}
agentName=${AGENT_NAME}
projectName=${PROJECT_NAME}

function setup_litmusctl(){
    curl -O https://litmusctl-bucket.s3-eu-west-1.amazonaws.com/litmusctl-linux-amd64-${litmusctlVersion}.tar.gz
    tar -zxvf litmusctl-linux-amd64-${litmusctlVersion}.tar.gz
    chmod +x litmusctl
    sudo mv litmusctl /usr/local/bin/litmusctl
    litmusctl version
}

function connect_agent_cs_mode() {

    echo -e "\n---------------Connecting Agent in Cluster Scope----------\n"
    
    litmusctl config set-account --endpoint="${accessPoint}" --username="admin" --password="litmus"
    
    projectID=$(litmusctl get projects | grep "${projectName}" |  awk '{print $1}')
    
    litmusctl create agent --agent-name=${namespace} --project-id=${projectID} --non-interactive 

}

function connect_agent_ns_mode(){

    echo -e "\n---------------Connecting Agent in Cluster Scope----------\n"
    
    kubectl create ns ${namespace}
    # Installing CRD's, required for namespaced mode
    kubectl apply -f https://raw.githubusercontent.com/litmuschaos/litmus/master/litmus-portal/litmus-portal-crds.yml
    
    litmusctl config set-account --endpoint=${accessPoint} --username="admin" --password="litmus"
    
    projectID=$(litmusctl get projects | grep ${projectName} |  awk '{print $1}')

    echo $projectID
    
    # litmusctl create agent --agent-name=${agentName} --project-id=${projectID} --installation-mode=namespace --namespace=${namespace} --non-interactive 
}


function wait_for_agent_to_be_ready(){

    echo -e "\n---------------Pods running in ${namespace} Namespace---------------\n"
    kubectl get pods -n ${namespace}

    echo -e "\n---------------Waiting for all pods to be ready---------------\n"
    # Waiting for pods to be ready (timeout - 360s)
    wait_for_pods ${namespace} 360

    echo -e "\n------------- Verifying Namespace, Deployments for External agent ------------------\n"
    # Namespace verification
    verify_namespace ${namespace}

    # Deployments verification
    verify_all_components subscriber,chaos-exporter,chaos-operator-ce,event-tracker,workflow-controller ${namespace}
}

if [[ "$setupCLI" == "true" ]];then
    setup_litmusctl
fi

if [[ "$installation_mode" == "CS-MODE" ]];then
    connect_agent_cs_mode
elif [[ "$installation_mode" == "NS-MODE" ]];then
    connect_agent_ns_mode
else
    echo "Selected Mode Not Found"
    exit 1
fi

# wait_for_agent_to_be_ready