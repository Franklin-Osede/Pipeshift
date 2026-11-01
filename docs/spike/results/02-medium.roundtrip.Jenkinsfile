pipeline {
  agent {
    label 'linux'
  }
  stages {
    stage('Checks') {
      failFast true
      parallel {
        stage('Lint') {
          steps {
            sh 'make lint'
          }
        }

        stage('Unit') {
          agent {
            label 'big'
          }
          post {
            always {
              echo 'unit finished'
            }

          }
          steps {
            sh 'make unit'
          }
        }

      }
    }

    stage('Deploy') {
      when {
        beforeAgent true
        branch 'main'
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
  environment {
    REGISTRY = 'registry.example.com'
    API_TOKEN = credentials('api-token-id')
  }
  post {
    always {
      echo 'done'
    }

    failure {
      sh './notify.sh failed'
    }

    unstable {
      echo 'unstable'
    }

    changed {
      echo 'changed'
    }

    fixed {
      echo 'fixed'
    }

    cleanup {
      sh 'rm -rf build'
    }

  }
  options {
    timeout(time: 30, unit: 'MINUTES')
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }
  parameters {
    string(name: 'TARGET', defaultValue: 'staging', description: 'Where to deploy')
  }
  triggers {
    cron('H 2 * * 1-5')
  }
}
