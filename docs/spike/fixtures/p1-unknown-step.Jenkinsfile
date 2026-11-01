pipeline {
    agent any
    stages {
        stage('Good') {
            steps { sh 'ok' }
        }
        stage('Unknown') {
            steps {
                slackSend channel: '#ci', message: 'hello'
                sh 'still here'
            }
        }
    }
}
