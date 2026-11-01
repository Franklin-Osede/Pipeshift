pipeline {
  agent any
  stages {
    stage('Build') {
      steps {
        sh 'make build'
        echo "Built ${APP_NAME}"
      }
    }

    stage('Test') {
      steps {
        sh 'make test'
      }
    }

  }
  environment {
    APP_NAME = 'demo'
  }
}
