// Fixture 02: the constructs the v1 rules must cover.
pipeline {
    agent { label 'linux' }
    triggers {
        cron('H 2 * * 1-5')
    }
    options {
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    parameters {
        string(name: 'TARGET', defaultValue: 'staging', description: 'Where to deploy')
    }
    environment {
        REGISTRY = 'registry.example.com'
        API_TOKEN = credentials('api-token-id')
    }
    stages {
        stage('Checks') {
            failFast true
            parallel {
                stage('Lint') {
                    steps { sh 'make lint' }
                }
                stage('Unit') {
                    agent { label 'big' }
                    steps { sh 'make unit' }
                    post {
                        always { echo 'unit finished' }
                    }
                }
            }
        }
        stage('Deploy') {
            when {
                branch 'main'
                beforeAgent true
            }
            environment {
                STAGE_ONLY = 'yes'
            }
            steps {
                sh """
                    ./deploy.sh --target ${params.TARGET}
                """
            }
        }
    }
    post {
        always { echo 'done' }
        failure { sh './notify.sh failed' }
        unstable { echo 'unstable' }
        changed { echo 'changed' }
        fixed { echo 'fixed' }
        cleanup { sh 'rm -rf build' }
    }
}
