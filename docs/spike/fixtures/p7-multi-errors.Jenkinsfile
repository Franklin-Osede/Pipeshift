pipeline {
    agent any
    stages {
        stage('Bad1') {
            steps { nosuchStepOne() }
        }
        stage('Bad2') {
        }
        stage('Bad1') {
            steps { sh 'duplicate stage name' }
        }
    }
    bogusSection { x }
}
