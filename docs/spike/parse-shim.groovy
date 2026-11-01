// Spike shim. Prepended with: def SRC = <decoded Jenkinsfile>
// Runs the plugin's own ModelParser under the plugin's own compiler config
// (GroovySandbox base config, which rejects @Grab, @ASTTest and similar), stops
// at the CONVERSION phase, and keeps the AST even when validation fails.
import groovy.json.JsonOutput
import java.security.CodeSource
import java.security.cert.Certificate
import org.codehaus.groovy.ast.ASTNode
import org.codehaus.groovy.ast.expr.MethodCallExpression
import org.codehaus.groovy.ast.stmt.ExpressionStatement
import org.codehaus.groovy.control.CompilationUnit
import org.codehaus.groovy.control.CompilePhase
import org.codehaus.groovy.control.MultipleCompilationErrorsException
import org.codehaus.groovy.control.SourceUnit
import org.codehaus.groovy.control.messages.ExceptionMessage
import org.codehaus.groovy.control.messages.SyntaxErrorMessage
import org.jenkinsci.plugins.pipeline.modeldefinition.ast.ModelASTElement
import org.jenkinsci.plugins.pipeline.modeldefinition.parser.Converter
import org.jenkinsci.plugins.pipeline.modeldefinition.parser.ModelParser

def elements = []
def seen = new HashSet()
def walk
walk = { o, String path ->
    if (o == null) return
    if (o instanceof Map) { o.each { k, v -> walk(k, path + '/key'); walk(v, path + '/' + k) }; return }
    if (o instanceof Collection) { o.eachWithIndex { v, i -> walk(v, path + '[' + i + ']') }; return }
    if (!(o instanceof ModelASTElement) || !seen.add(System.identityHashCode(o))) return
    def loc = o.sourceLocation
    elements << [path: path, type: o.getClass().simpleName,
                 line: loc instanceof ASTNode ? loc.lineNumber : null,
                 col: loc instanceof ASTNode ? loc.columnNumber : null,
                 lastLine: loc instanceof ASTNode ? loc.lastLineNumber : null]
    o.metaClass.properties.findAll { it.name != 'class' && it.name != 'sourceLocation' && it.getter != null }.each {
        def v = null
        try { v = it.getProperty(o) } catch (Throwable t) { return }
        walk(v, path + '.' + it.name)
    }
}

def model = new Object[1]
def unit = new Object[1]
def fatal = null
def cu = new CompilationUnit(Converter.makeCompilerConfiguration(),
    new CodeSource(new URL('file', '', '/groovy/shell'), (Certificate[]) null),
    Converter.getCompilationClassLoader())
cu.addSource('WorkflowScript', SRC)
cu.addPhaseOperation(new CompilationUnit.SourceUnitOperation() {
    @Override void call(SourceUnit s) {
        unit[0] = s
        if (model[0] == null) model[0] = new ModelParser(s, []).parse(true)
    }
}, CompilePhase.CONVERSION.phaseNumber)
try { cu.compile(CompilePhase.CONVERSION.phaseNumber) }
catch (MultipleCompilationErrorsException e) { }
catch (Throwable t) { fatal = t.toString() }

def errors = []
def collector = unit[0]?.errorCollector ?: cu.errorCollector
(collector?.errors ?: []).each { m ->
    if (m instanceof SyntaxErrorMessage) {
        def c = m.cause
        errors << [message: c.originalMessage, line: c.line, col: c.startColumn]
    } else if (m instanceof ExceptionMessage) {
        errors << [message: m.cause.toString(), line: null, col: null]
    } else {
        errors << [message: m.toString(), line: null, col: null]
    }
}

def top = [imports: [], statements: [], classes: [], methods: []]
def ast = unit[0]?.AST
if (ast != null) {
    def lines = SRC.readLines()
    ast.imports.each { top.imports << [className: it.className, line: it.lineNumber, annotations: it.annotations*.classNode*.name] }
    ast.statementBlock.statements.each { st ->
        def isPipeline = st instanceof ExpressionStatement && st.expression instanceof MethodCallExpression && st.expression.methodAsString == 'pipeline'
        if (!isPipeline && st.lineNumber > 0) top.statements << [line: st.lineNumber, text: lines[st.lineNumber - 1].trim()]
    }
    ast.classes.findAll { !it.isScript() }.each { top.classes << [name: it.name, line: it.lineNumber] }
    ast.methods.findAll { it.lineNumber > 0 }.each { top.methods << [name: it.name, line: it.lineNumber] }
}

if (model[0] != null) walk(model[0], 'pipeline')
def json = null
try { json = model[0]?.toJSON()?.toString() } catch (Throwable t) { json = null; errors << [message: 'toJSON failed: ' + t, line: null, col: null] }
println JsonOutput.toJson([astBuilt: model[0] != null, fatal: fatal, errors: errors, topLevel: top, elements: elements, json: json])
