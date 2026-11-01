# Parser-only Jenkins. No jobs, no agents, no network at runtime.
# The digest is the multi-arch manifest for 2.580.2-lts-jdk21.
FROM jenkins/jenkins:2.580.2-lts-jdk21@sha256:74401de6a6f92e1afe1b02d1c8e3d0c33f263bfb5275dd8813f9150355f2367b

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.model.UpdateCenter.never=true -Xmx768m"

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt --latest false
