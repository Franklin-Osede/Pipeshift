// Fixture 01: smallest realistic declarative pipeline.
pipeline {
    agent any
    environment {
        APP_NAME = 'demo'
    }
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
}
