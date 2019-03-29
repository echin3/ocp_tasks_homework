#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

#GUID=$1
GUID=eac
#REPO=$2
REPO=https://github.com/echin3/ocp_tasks_homework.git
#CLUSTER=$3
CLUSTER=master.na311.openshift.opentlc.com

echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources

oc new-app jenkins-persistent -p ENABLE_OAUTH=true -p MEMORY_LIMIT=2Gi -p VOLUME_CAPACITY=4Gi -p DISABLE_ADMINISTRATIVE_MONITORS=true

# Create custom agent container image with skopeo

oc new-build -D $'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11\nUSER root\nRUN yum install -y skopeo && yum clean all\nUSER 1001' --name=jenkins-agent-appdev -n eac-jenkins

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
echo "apiVersion: v1
items:
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "tasks-pipeline"
  spec:
    source:
      type: "Git"
      git:
        uri: "https://github.com/echin3/ocp_tasks_homework/tree/master/openshift-tasks"
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        jenkinsfilePath: openshift-tasks/Jenkinsfile
kind: List
metadata: []" | oc create -f -n eac-jenkins

# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done
