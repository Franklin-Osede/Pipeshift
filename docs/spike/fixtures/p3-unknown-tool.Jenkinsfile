pipeline {
    agent any
    tools {
        maven 'mvn-3.9'
        jdk 'jdk-21'
    }
    stages {
        stage('A') {
            steps { sh 'mvn -v' }
        }
    }
}
