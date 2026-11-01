// Benign probe: does compile-time AST code run during toJson?
import groovy.transform.ASTTest
import org.codehaus.groovy.control.CompilePhase
@ASTTest(phase=CompilePhase.SEMANTIC_ANALYSIS, value={ new File('/tmp/pipeshift-probe-asttest').text = 'ran' })
def marker = 1
pipeline {
    agent any
    stages {
        stage('A') {
            steps { sh 'ok' }
        }
    }
}
