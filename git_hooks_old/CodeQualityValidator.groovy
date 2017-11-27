import javax.xml.xpath.*
import javax.xml.parsers.*
import java.nio.charset.StandardCharsets
import org.codehaus.groovy.control.*
import org.codehaus.groovy.control.customizers.*

class CodeQualityValidator {
    
    static {
        System.setProperty("javax.xml.xpath.XPathFactory:" + net.sf.saxon.lib.NamespaceConstant.OBJECT_MODEL_SAXON, "net.sf.saxon.xpath.XPathFactoryImpl");
    }
    
    def xmlDocBuilder = null
    def xpath = null
    def fileDoc = null
    def fileContentProvider = null
    def shell = null
    def codeQualityConfiguration = null
    //rule cache per file type
    def ruleCache = [:]
    def overallValidationResult = []
    def validationResultIsBlocker = false
    def numFailedValidations = 0
    
    public CodeQualityValidator(fileContentProvider) {
        this.fileContentProvider = fileContentProvider

        //0 - Initialize common stuff
        def xmlDocBuilderFactory = DocumentBuilderFactory.newInstance()
        xmlDocBuilderFactory.setNamespaceAware(true);
        xmlDocBuilderFactory.setValidating(false);
        xmlDocBuilder = xmlDocBuilderFactory.newDocumentBuilder()
        xpath = XPathFactory.newInstance(net.sf.saxon.lib.NamespaceConstant.OBJECT_MODEL_SAXON).newXPath()

        def conf = new CompilerConfiguration()
        //def customizer = new ImportCustomizer()
        //customizer.addStaticStars("java.lang.Math")
        //conf.addCompilationCustomizers(customizer)
        def binding = new Binding()
        def yodelDomains = ["client", "shipping", "fulfilment", "finance", "hr", "transport", "mi", "change", "it"]
        def serviceLayers = ["pres", "bp", "ba", "data", "infra", "anl"]
        def serviceGroups = ["Spectrum_Common", "Spectrum_ScanServices", "Spectrum_EventServices", "Spectrum_QueryServices", "Spectrum_ReferenceDataServices", "Spectrum_ErrorServices"]
        binding.setVariable("yodelDomains", yodelDomains)
        binding.setVariable("serviceLayers", serviceLayers)
        binding.setVariable("serviceGroups", serviceGroups)
        binding.setVariable("fileDoc", fileDoc)
        binding.evalStringXPath = { String expression -> 
            def xpathExpr = xpath.compile(expression)
            return xpathExpr.evaluate(fileDoc, XPathConstants.STRING)
        }
        shell = new GroovyShell(binding, conf)

        //1 Parse configuration XML
        codeQualityConfiguration = new XmlSlurper().parseText(new File("CodeQualityRules.xml").text)
        println "Applying code quality configuration: ${codeQualityConfiguration.Description}"

        //2 Preload configuration bits
        //2.1 Namespace contextg
        def namespaces = [:]
        for (namespaceContext in codeQualityConfiguration.NamespaceContext.Xmlns) {
            //println "Processing namespace declaration::\t${namespaceContext.@prefix}\t${namespaceContext.@namespace}"
            namespaces[namespaceContext.@prefix.text()] = namespaceContext.@namespace.text()
        }
        def nsContext = new CCNamespaceContext(namespaces)
        xpath.setNamespaceContext(nsContext)
        //2.2 Rules
        for (fileType in codeQualityConfiguration.FileTypes.FileType) {
            def fileTypeName = fileType.@name.toString()
            //println "Caching rules for file type ${fileTypeName}"
            def fileTypeRuleCache = ruleCache[fileTypeName]
            if (fileTypeRuleCache == null) {
                fileTypeRuleCache = []
                ruleCache[fileTypeName] = fileTypeRuleCache
            }
            for (rule in fileType.Rule) {
                //println "\tCaching rule ${rule.@name}"
                def ruleObj = [
                      name: rule.@name.text()
                    , filter: rule.@filter.text()
                    , severity: rule.@severity.text()
                    , type: rule.@type.text()
                    , errorMessage : rule.@errorMessage.text().trim()
                    , text: rule.@type.text().startsWith("xpath") ? rule.text().replace("\n", " ") : rule.text()
                ]
                fileTypeRuleCache.add ruleObj
            }
        }
    }

    public void performValidation() {
        validationResultIsBlocker = false
        overallValidationResult = []
        def overallSuccess = true
        //3 For each file type
        def currentFile = fileContentProvider.nextFile()
        while (currentFile != null) {
            println "Processing file ${currentFile.name}"
            def fileTypeName = deriveFileType(currentFile)
            if (fileTypeName != null) {
                def fileTypeRuleCache = ruleCache[fileTypeName]
                //println "Derived file type::\t${fileTypeName} (${fileTypeRuleCache == null? 0 : fileTypeRuleCache.size()} rules)"
                //3.2.1 parse the file
                fileDoc = xmlDocBuilder.parse(new ByteArrayInputStream(currentFile.text.getBytes(StandardCharsets.UTF_8))).documentElement
                //3.2.2 for each rule ref apply all the rules that match the filter
                for (rule in fileTypeRuleCache) {
                    //println "\t\tChecking whether to apply rule: ${rule.name} ... "
                    def filterResult = (Boolean) xpath.compile(rule.filter).evaluate(fileDoc, XPathConstants.BOOLEAN)
                    //println "\tFilter evaluation result: ${filterResult}"
                    if (filterResult) {
                        def validationResult = [
                                  fileName: currentFile.name
                                , filePath: currentFile.path
                                , fileType: fileTypeName
                                , ruleName: rule.name
                                , validationPassed: null
                                , ruleSeverityLevel: rule.severity
                                , errors: null
                            ]
                        //println "\t\t\tApplying rule :: ${rule.name}"
                        if (rule.type == "xpathBoolean") {
                            def ruleExpr = xpath.compile(rule.text)
                            def ruleResult = ruleExpr.evaluate(fileDoc, XPathConstants.BOOLEAN)
                            validationResult.validationPassed = ruleResult
                            validationResult.errors = [rule.errorMessage]
                            if (!ruleResult) {
                                overallSuccess = false
                            }
                        } else if (rule.type == "xpathNodes") {
                            def ruleExpr = xpath.compile(rule.text)
                            def ruleResult = ruleExpr.evaluate(fileDoc, XPathConstants.NODESET)
                            if (ruleResult != null && ruleResult.getLength() > 0) {
                                overallSuccess = false
                                def failedNodeNames = []
                                for (nodeIndex in 0 .. ruleResult.getLength() - 1) {
                                    failedNodeNames.add ruleResult.item(nodeIndex).getNodeValue()
                                }
                                validationResult.validationPassed = false
                                validationResult.errors = ["${rule.errorMessage}. Failed items: ${failedNodeNames}"]
                            } else {
                                //println "\t\t\tRule evaluates to ${ruleResult}. Rule passed"
                                validationResult.validationPassed = true
                                validationResult.errors = []
                            }
                        } else if (rule.type == "groovy") {
                            def groovyResult = shell.evaluate(rule.text)
                            if (groovyResult != null && groovyResult.size() > 0) {
                                validationResult.validationPassed = false
                                validationResult.errors = groovyResult
                                overallSuccess = false
                            } else {
                                validationResult.validationPassed = true
                                validationResult.errors = []
                            }
                        }
                        if (!validationResult.validationPassed) {
                            println "\t\t\t${rule.severity.toUpperCase()}(S): ${rule.name} :: ${validationResult.errors}"
                        }
                        addResult(validationResult)
                    }
                }
            }
            currentFile = fileContentProvider.nextFile()
        }
    }
    
    def deriveFileType(file) {
        def fileName = file.name
        if (fileName.endsWith(".xsd")) {
            return "XSD"
        } else if (fileName.endsWith(".wsdl")) {
            return "WSDL"
        } else if (fileName.endsWith(".proxy")) {
            return "OsbProxyService"
        } else if (fileName.endsWith(".biz")) {
            return "OsbBusinessService"
        } else if (fileName.endsWith("pom.xml")) {
            return "MavenPOM"
        } else {
            //def dotIndex = fileName.lastIndexOf('.')
            //return fileName.substring(dotIndex + 1)
            return null
        }
    }
    
    def addResult(validationResult) {
        overallValidationResult.add(validationResult)
        if (!validationResult.validationPassed) {
            numFailedValidations += 1
            if (validationResult.ruleSeverityLevel != "info" && validationResult.ruleSeverityLevel != "warning") {
                validationResultIsBlocker = true
            }
        }
    }
    
    def getValidationResults() {
        return overallValidationResult
    }
    
    def isValidationResultBlocker() {
        return validationResultIsBlocker
    }

    def isValidationFullyPassed() {
        return numFailedValidations == 0
    }
    
}
