#!/usr/bin/env groovy
def baseFolder = args[0]
def contentProvider = new FileSystemContentProvider(baseFolder)
def codeQualityValidator = new CodeQualityValidator(contentProvider)
codeQualityValidator.performValidation()
if (!codeQualityValidator.isValidationFullyPassed()) {
//    def reportGenerator = new CodeQualityReportGenerator(codeQualityValidator.getValidationResults(), baseFolder)
//    reportGenerator.saveToExcelFormat(new File('/tmp/report.xlsx'))
//    def offendersEmailProc = "git --no-pager show -s --format=\"%aE\" ${newrev}".execute()
//    offendersEmailProc.waitFor()
//    def offendersEmail = offendersEmailProc.text

    if (codeQualityValidator.isValidationResultBlocker()) {
        println "Blocking errors found during the validation of the code quality. Please fix them before pushing"
        //TODO: send email with the report results
        System.exit(1)
    } else {
        println "Some non-blocking errors found during the validation of the pushed changes. Please see report and bear them in mind"
    }
}
