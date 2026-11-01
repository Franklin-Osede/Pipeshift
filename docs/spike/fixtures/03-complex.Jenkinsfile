// Fixture 03: embedded Groovy, nesting, matrix, credentials and hard semantics.
def helper = 'outside the pipeline block'

pipeline {
    agent none
    libraries {
        lib('not-a-real-lib@main')
    }
    stages {
        stage('Container') {
            agent {
                docker {
                    image 'golang:1.26'
                    args '-v /cache:/cache'
                }
            }
            steps {
                script {
                    def targets = ['a', 'b']
                    for (t in targets) {
                        sh "build ${t}"
                    }
                    env.COMPUTED = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                }
                withCredentials([usernamePassword(credentialsId: 'db', usernameVariable: 'U', passwordVariable: 'P')]) {
                    sh 'login "$U" "$P"'
                }
                stash name: 'bin', includes: 'bin/**'
            }
        }
        stage('Matrix') {
            matrix {
                agent any
                axes {
                    axis {
                        name 'OS'
                        values 'linux', 'mac'
                    }
                }
                excludes {
                    exclude {
                        axis {
                            name 'OS'
                            values 'mac'
                        }
                    }
                }
                stages {
                    stage('Run') {
                        steps { sh "run-on ${OS}" }
                    }
                }
            }
        }
        stage('Sequential nested') {
            agent any
            stages {
                stage('Inner one') {
                    steps { sh 'one' }
                }
                stage('Inner two') {
                    steps { sh 'two' }
                }
            }
        }
        stage('Conditional') {
            agent any
            when {
                allOf {
                    anyOf {
                        branch pattern: 'release-\\d+', comparator: 'REGEXP'
                        tag 'v*'
                    }
                    not { changeRequest() }
                    expression { return env.COMPUTED?.length() > 3 && currentBuild.previousBuild != null }
                }
            }
            input {
                message 'Ship it?'
                submitter 'ops'
            }
            steps {
                retry(3) {
                    timeout(time: 5, unit: 'MINUTES') {
                        sh './ship.sh'
                    }
                }
            }
        }
    }
}
