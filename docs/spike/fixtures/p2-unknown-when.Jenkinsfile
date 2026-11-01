pipeline {
    agent any
    stages {
        stage('A') {
            when { someVendorCondition 'x' }
            steps { sh 'ok' }
        }
    }
}
