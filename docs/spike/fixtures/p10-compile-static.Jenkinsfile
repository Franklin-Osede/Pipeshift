// Benign probe: does a class static initializer run during toJson?
class Marker {
    static { new File('/tmp/pipeshift-probe-static').text = 'ran' }
}
pipeline {
    agent any
    stages {
        stage('A') {
            steps { sh 'ok' }
        }
    }
}
