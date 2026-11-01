// Benign probe: does @Grab get resolved during toJson?
@Grab('org.example:does-not-exist:1.0')
import org.example.Nope
pipeline {
    agent any
    stages {
        stage('A') {
            steps { sh 'ok' }
        }
    }
}
