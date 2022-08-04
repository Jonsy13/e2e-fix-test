/// <reference types="Cypress" />

let adminAccessToken, adminProjectId;
let workflowNames = [];
let namespacedDelegates = ["d-1", "d-2", "d-3"]

describe("Logging In as Admin, fetching admin-access-token & project-id",()=>{
    it("Token setup",()=>{
      cy.getAccessToken("admin", "litmus")
      .then((token)=> {
        adminAccessToken = token
        cy.createProject("admin's project", adminAccessToken).then((projectID)=> adminProjectId = projectID)
        cy.setCookie("litmus-cc-token", adminAccessToken);
      })
    })
})

describe("Connecting 3 namespaced scopes delegates along with target app: nginx",()=>{
    namespacedDelegates.map((agentName)=>{
        it(`Connecting namespaced delegate : ${agentName}`,()=>{
            cy.createNamespaceAgent(agentName, adminProjectId, adminAccessToken, agentName);
            cy.createTargetApplication(agentName, "target-app", "nginx");
        })
    })
})

describe("Running 5-5 workflows on 3 different namespaced delegates for calculation of resources & limits",()=>{
    namespacedDelegates.map((agentName)=>{
        for (var i = 0; i < 5 ; i++) {
            it(`Running ${i}th workflow on ${agentName} delegate`, () => {
                cy.waitForCluster(agentName);
                cy.visit("/create-scenario")
                cy.chooseAgent(agentName);
    
                cy.get("[data-cy=ControlButtons] Button").eq(0).click();
                cy.chooseWorkflow(2, 0);
            
                cy.configureWorkflowSettings(
                  "name",
                  "description",
                  0
                );

                cy.get("[data-cy=ControlButtons] Button").eq(1).click();

                cy.get("[data-cy=addExperimentButton]").should("be.visible");
                cy.get("[data-cy=addExperimentButton]").click();
                cy.get("[data-cy=addExperimentSearch]").should("be.visible");
                cy.get("[data-cy=addExperimentSearch]")
                  .find("input")
                  .clear()
                  .type("generic");
                cy.get("[data-cy=ExperimentList] :radio").eq(0).check();
                cy.get("[data-cy=AddExperimentDoneButton]").click();

                cy.wait(1000);

                cy.get("table").find("tr").eq(1).find("td").eq(0).click();

                const tunningParameters = {
                  general: {
                    hubName: "Litmus ChaosHub",
                    experimentName: "pod-delete",
                    context: `pod-delete_${agentName}`,
                  },
                  targetApp: {
                    annotationCheckToggle: false,
                    appns: agentName,
                    appKind: "deployment",
                    appLabel: "app=nginx",
                  },
                  steadyState: {},
                  tuneExperiment: {
                    totalChaosDuration: 30,
                    chaosInterval: 10,
                    force: "false",
                  },
                };

                cy.tuneCustomWorkflow(tunningParameters);

                // Expected nodes
                const graphNodesNameArray = ["install-chaos-experiments", "pod-delete"];

                cy.get("[data-cy=revertChaosSwitch] input").click();

                // Verify nodes in dagre graph
                cy.validateGraphNodes(graphNodesNameArray);

                cy.get("[data-cy=ControlButtons] Button").eq(1).click();

                cy.rScoreEditor(5);

                cy.get("[data-cy=ControlButtons] Button").eq(1).click();

                cy.selectSchedule(0);

                cy.get("[data-cy=ControlButtons] Button").eq(1).click();

                cy.verifyDetails(
                  "name",
                  "description",
                  0
                );

                cy.get("[data-cy=ControlButtons] Button").eq(0).click(); // Clicking on finish Button

                cy.get("[data-cy=FinishModal]").should("be.visible");
                cy.get("[data-cy=WorkflowName]").then(($name) => {
                  workflowNames.push({name: $name.text(), namespace: agentName});
                  return;
                });

                cy.get("[data-cy=GoToWorkflowButton]").click();
            })
        }
    })
})



