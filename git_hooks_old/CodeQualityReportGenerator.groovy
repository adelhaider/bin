import java.util.*

import org.apache.poi.ss.usermodel.*
import org.apache.poi.xssf.usermodel.*
import org.apache.poi.hssf.util.*


class CodeQualityReportGenerator {

    def validationResults = null;
    def baseFolder = null;

    def COLUMN_GROUP = 0
    def COLUMN_ARTIFACT = 1
    def COLUMN_FILE_PATH = 2
    def COLUMN_FILE_NAME = 3
    def COLUMN_FILE_TYPE = 4
    def COLUMN_RULE_NAME = 5
    def COLUMN_RULE_RESULT = 6
    def COLUMN_RULE_SEVERITY = 7
    def COLUMN_ERRORS = 8
    def SEVERITY_LEVELS = ["Critical", "Error", "Warning", "Info"]

    //excel specific variables
    def titleCellStyle = null
    def rulePassedCellStyle = null
    def ruleNotPassedCellStyle = null
    def neutralCellStyle = null
    def neutralCenteredCellStyle = null
    def severityCellStyles = [:]

    def severityColors = [:]
    
    public CodeQualityReportGenerator(validationResult, baseFolder) {
        this.validationResults = validationResult
        this.baseFolder = baseFolder
    }
    
    def saveToExcelFormat(file) {
        def workbook = new XSSFWorkbook()
        //buildColors(workbook)
        buildCellStyles(workbook)
        buildSumarySheet(workbook)
        buildCompleteReportSheet(workbook)
        def out = new FileOutputStream(file)
        workbook.write(out)
        out.flush()
        out.close()
    }
   
    def criticalColor = new XSSFColor(new java.awt.Color(255, 51, 51))
    def criticalFontColor = new XSSFColor(new java.awt.Color(95, 2, 2))
    def errorColor = new XSSFColor(new java.awt.Color(255, 102, 102))
    def warningColor = new XSSFColor(new java.awt.Color(255, 255, 230))
    def warningFontColor = new XSSFColor(new java.awt.Color(255, 172, 88))
    def infoColor = new XSSFColor(new java.awt.Color(179, 230, 255))
    def infoFontColor = new XSSFColor(new java.awt.Color(79, 130, 155))
    def ruleNotPassedColor = new XSSFColor(new java.awt.Color(255, 102, 102))
    def ruleNotPassedFontColor = new XSSFColor(new java.awt.Color(95, 2, 2))
    def rulePassedColor = new XSSFColor(new java.awt.Color(179, 255, 179))
    def rulePassedFontColor = new XSSFColor(new java.awt.Color(29, 105, 29))
    
    def buildSumarySheet(workbook) {
        def validationFailureCounts = [:]
        def validationFailureCountsPerArtifact = [:]
        def totalValidationsApplied = 0
        def allFiles = []
        def allArtifacts = []
        def allFailedFiles = []
        
        for (validationResult in validationResults) {
            def fileDetails = processFileDetails(validationResult.filePath, validationResult.fileName)
            allArtifacts.add(fileDetails.artifactId)
            allFiles.add(validationResult.filePath + '/' + validationResult.fileName)
            if (!validationResult.validationPassed) {
                //count of failed files
                allFailedFiles.add(validationResult.filePath + '/' + validationResult.fileName)

                //overall couts per severity level
                def previousValidationFailureCount = validationFailureCounts[validationResult.ruleSeverityLevel]
                if (previousValidationFailureCount == null) previousValidationFailureCount = 0
                validationFailureCounts[validationResult.ruleSeverityLevel] = previousValidationFailureCount + 1

                //overall counts per artifact id and severity
                def validationFailureCountsForThisArtifact = validationFailureCountsPerArtifact[fileDetails.artifactId]
                if (validationFailureCountsForThisArtifact == null) {
                    validationFailureCountsForThisArtifact = [:]
                    validationFailureCountsPerArtifact[fileDetails.artifactId] = validationFailureCountsForThisArtifact
                }
                def validationFailureCountForThisArtifactAndSeverity = validationFailureCountsForThisArtifact[validationResult.ruleSeverityLevel]
                if (validationFailureCountForThisArtifactAndSeverity == null) {
                    validationFailureCountForThisArtifactAndSeverity = 0
                }
                validationFailureCountsForThisArtifact[validationResult.ruleSeverityLevel] = validationFailureCountForThisArtifactAndSeverity + 1
            }
            totalValidationsApplied += 1
        }
        
        def sheet = workbook.createSheet("Summary")
        sheet.setColumnWidth(0, 256 * 30);
        sheet.setColumnWidth(1, 256 * 12);

        //titles
        def firstRow = getRow(sheet, 0);
        createRowCell(firstRow, 0, "Code quality validation sumary:", titleCellStyle)

        //file counts
        def baseCountsRow = 2
        def fileCountRow = getRow(sheet, baseCountsRow)
        createRowCell(fileCountRow, 0, "Total file count:", titleCellStyle)
        createRowCell(fileCountRow, 1, allFiles.unique().size(), neutralCenteredCellStyle)
        def failedFileCountRow = getRow(sheet, baseCountsRow + 1)
        createRowCell(failedFileCountRow, 0, "Total failed file count:", titleCellStyle)
        createRowCell(failedFileCountRow, 1, allFailedFiles.unique().size(), neutralCenteredCellStyle)

        //violation counts
        def baseDataRow = 5
        def detailsRow = getRow(sheet, baseDataRow);
        def severityColumnIndex = 1
        for (severityName in SEVERITY_LEVELS) {
            setCell(sheet, baseDataRow, severityColumnIndex++, severityName, severityCellStyles[severityName.toLowerCase()])
        }
        def artifactRowIndex = baseDataRow + 1
        for (artifactId in validationFailureCountsPerArtifact.keySet()) {
            setCell(sheet, artifactRowIndex, 0, artifactId, titleCellStyle)
            severityColumnIndex = 1
            def validationFailureCountsForCurrentArtifact = validationFailureCountsPerArtifact[artifactId]
            for (severityName in SEVERITY_LEVELS) {
                def severityNameLc = severityName.toLowerCase()
                def numViolations = nonNullNum(validationFailureCountsForCurrentArtifact[severityNameLc])
                setCell(sheet, artifactRowIndex, severityColumnIndex++, numViolations, numViolations > 0? severityCellStyles[severityNameLc] : neutralCenteredCellStyle)
            }
            artifactRowIndex++
        }
        
        severityColumnIndex = 1
        setCell(sheet, artifactRowIndex, 0, "TOTAL", titleCellStyle)
        for (severityName in SEVERITY_LEVELS) {
            def severityNameLc = severityName.toLowerCase()
            def numViolations = nonNullNum(validationFailureCounts[severityNameLc])
            setCell(sheet, artifactRowIndex, severityColumnIndex++, numViolations, numViolations > 0? severityCellStyles[severityNameLc] : neutralCenteredCellStyle)
        }
    }
    
    def nonNullNum(value) {
        return value == null? 0 : value
    }

    def buildCellStyles(workbook) {
        def font

        neutralCellStyle = workbook.createCellStyle()
        neutralCellStyle.setWrapText(true);
        neutralCellStyle.setVerticalAlignment(XSSFCellStyle.VERTICAL_TOP)
        neutralCellStyle.setAlignment(CellStyle.ALIGN_LEFT)

        neutralCenteredCellStyle = workbook.createCellStyle()
        neutralCenteredCellStyle.setWrapText(true);
        neutralCenteredCellStyle.setVerticalAlignment(XSSFCellStyle.VERTICAL_TOP)
        neutralCenteredCellStyle.setAlignment(CellStyle.ALIGN_CENTER)

        titleCellStyle = workbook.createCellStyle()
        titleCellStyle.setWrapText(true);
        titleCellStyle.setFillForegroundColor(IndexedColors.LIGHT_BLUE.getIndex())
        titleCellStyle.setFillPattern(XSSFCellStyle.SOLID_FOREGROUND)
        font = workbook.createFont()
        font.setColor(IndexedColors.WHITE.getIndex())
        titleCellStyle.setFont(font)
        titleCellStyle.setVerticalAlignment(XSSFCellStyle.VERTICAL_TOP)

        rulePassedCellStyle = workbook.createCellStyle()
        rulePassedCellStyle.setWrapText(true);
        rulePassedCellStyle.setFillForegroundColor(rulePassedColor)
        rulePassedCellStyle.setFillPattern(XSSFCellStyle.SOLID_FOREGROUND)
        font = workbook.createFont()
        font.setColor(rulePassedFontColor)
        rulePassedCellStyle.setFont(font)
        rulePassedCellStyle.setAlignment(CellStyle.ALIGN_CENTER)
        rulePassedCellStyle.setVerticalAlignment(XSSFCellStyle.VERTICAL_TOP)

        ruleNotPassedCellStyle = workbook.createCellStyle()
        ruleNotPassedCellStyle.setWrapText(true);
        ruleNotPassedCellStyle.setFillForegroundColor(ruleNotPassedColor)
        ruleNotPassedCellStyle.setFillPattern(XSSFCellStyle.SOLID_FOREGROUND)
        font = workbook.createFont()
        font.setColor(ruleNotPassedFontColor)
        ruleNotPassedCellStyle.setFont(font)
        ruleNotPassedCellStyle.setAlignment(CellStyle.ALIGN_CENTER)
        ruleNotPassedCellStyle.setVerticalAlignment(XSSFCellStyle.VERTICAL_TOP)

        def severityCellStyle
        severityCellStyle = workbook.createCellStyle()
        severityCellStyle.setWrapText(true);
        severityCellStyle.setFillForegroundColor(criticalColor)
        severityCellStyle.setFillPattern(XSSFCellStyle.SOLID_FOREGROUND)
        font = workbook.createFont()
        font.setColor(criticalFontColor)
        severityCellStyle.setFont(font)
        severityCellStyle.setAlignment(CellStyle.ALIGN_CENTER)
        severityCellStyle.setVerticalAlignment(XSSFCellStyle.VERTICAL_TOP)
        severityCellStyles['critical'] = severityCellStyle

        severityCellStyle = workbook.createCellStyle()
        severityCellStyle.setWrapText(true);
        severityCellStyle.setFillForegroundColor(errorColor)
        severityCellStyle.setFillPattern(XSSFCellStyle.SOLID_FOREGROUND)
        font = workbook.createFont()
        font.setColor(IndexedColors.WHITE.getIndex())
        severityCellStyle.setFont(font)
        severityCellStyle.setAlignment(CellStyle.ALIGN_CENTER)
        severityCellStyle.setVerticalAlignment(XSSFCellStyle.VERTICAL_TOP)
        severityCellStyles['error'] = severityCellStyle

        severityCellStyle = workbook.createCellStyle()
        severityCellStyle.setWrapText(true);
        severityCellStyle.setFillForegroundColor(warningColor)
        severityCellStyle.setFillPattern(XSSFCellStyle.SOLID_FOREGROUND)
        font = workbook.createFont()
        font.setColor(warningFontColor)
        severityCellStyle.setFont(font)
        severityCellStyle.setAlignment(CellStyle.ALIGN_CENTER)
        severityCellStyle.setVerticalAlignment(XSSFCellStyle.VERTICAL_TOP)
        severityCellStyles['warning'] = severityCellStyle

        severityCellStyle = workbook.createCellStyle()
        severityCellStyle.setWrapText(true);
        severityCellStyle.setFillForegroundColor(infoColor)
        severityCellStyle.setFillPattern(XSSFCellStyle.SOLID_FOREGROUND)
        font = workbook.createFont()
        font.setColor(infoFontColor)
        severityCellStyle.setFont(font)
        severityCellStyle.setAlignment(CellStyle.ALIGN_CENTER)
        severityCellStyle.setVerticalAlignment(XSSFCellStyle.VERTICAL_TOP)
        severityCellStyles['info'] = severityCellStyle
    }

    def buildCompleteReportSheet(workbook) {
        print 'saving'
        def sheet = workbook.createSheet("Complete report");
        sheet.setColumnWidth(COLUMN_GROUP, 256 * 30)
        sheet.setColumnWidth(COLUMN_ARTIFACT, 256 * 30)
        sheet.setColumnWidth(COLUMN_FILE_PATH, 256 * 40)
        sheet.setColumnWidth(COLUMN_FILE_NAME, 256 * 30)
        sheet.setColumnWidth(COLUMN_FILE_TYPE, 256 * 13)
        sheet.setColumnWidth(COLUMN_RULE_NAME, 256 * 25)
        sheet.setColumnWidth(COLUMN_RULE_RESULT, 256 * 10)
        sheet.setColumnWidth(COLUMN_RULE_SEVERITY, 256 * 12)
        sheet.setColumnWidth(COLUMN_ERRORS, 256 * 255)
        
        //title row
        def firstRow = getRow(sheet, 0);

        createRowCell(firstRow, COLUMN_GROUP, "Group", titleCellStyle)
        createRowCell(firstRow, COLUMN_ARTIFACT, "Artifact", titleCellStyle)
        createRowCell(firstRow, COLUMN_FILE_PATH, "File path", titleCellStyle)
        createRowCell(firstRow, COLUMN_FILE_NAME, "File nane", titleCellStyle)
        createRowCell(firstRow, COLUMN_FILE_TYPE, "File type", titleCellStyle)
        createRowCell(firstRow, COLUMN_RULE_NAME, "Rule name", titleCellStyle)
        createRowCell(firstRow, COLUMN_RULE_RESULT, "Result", titleCellStyle)
        createRowCell(firstRow, COLUMN_RULE_SEVERITY, "Severity", titleCellStyle)
        createRowCell(firstRow, COLUMN_ERRORS, "Errors", titleCellStyle)

        int i = 1;
        for (validationResult in validationResults) {
            print '.'
            def row = getRow(sheet, i);
            def fileDetails = processFileDetails(validationResult.filePath, validationResult.fileName)
            createRowCell(row, COLUMN_GROUP, fileDetails.group, neutralCellStyle)
            createRowCell(row, COLUMN_ARTIFACT, fileDetails.artifactId, neutralCellStyle)
            createRowCell(row, COLUMN_FILE_PATH, fileDetails.path, neutralCellStyle)
            createRowCell(row, COLUMN_FILE_NAME, validationResult.fileName, neutralCellStyle)
            createRowCell(row, COLUMN_FILE_TYPE,validationResult.fileType, neutralCellStyle)
            createRowCell(row, COLUMN_RULE_NAME, validationResult.ruleName, neutralCellStyle)
            createRowCell(row, COLUMN_RULE_RESULT, validationResult.validationPassed? "PASS" : "FAIL", validationResult.validationPassed? rulePassedCellStyle : ruleNotPassedCellStyle)
            createRowCell(row, COLUMN_RULE_SEVERITY, validationResult.ruleSeverityLevel, severityCellStyles[validationResult.ruleSeverityLevel])
            createRowCell(row, COLUMN_ERRORS, validationResult.errors.join('\n'), neutralCellStyle)

            i++;
        }
        sheet.setAutoFilter(new CellRangeAddress(0, i - 1, 0, COLUMN_ERRORS));
        println '.'
    }
    
    def processFileDetails(path, name) {
        def relativePath = (baseFolder != null ? path.replace(baseFolder, "").substring(1) : path).replace(name, "")
        def relativePathParts = relativePath.split('/')
        def osbProjectName = relativePathParts[0]
        def slashIndex = relativePath.indexOf('/')
        if (osbProjectName.startsWith("Common_")) {
            def osbProjectNameParts = osbProjectName.split('_')
            return [
                  artifactId: osbProjectNameParts[1]
                , path: relativePath + '/' + name
                , group: "Common"
            ]
        } else {
            return [
                  artifactId: relativePathParts.length > 3? "${relativePathParts[2]}_${relativePathParts[3]}" : ""
                , path: relativePathParts.length == 1? relativePath : relativePath.substring(slashIndex + 1)
                , group: relativePathParts[0]
            ]
        }
    }
    
    def getRow(sheet, rowIndex) {
        def requestedRow = sheet.getRow(rowIndex);
        if (requestedRow == null) {
            sheet.createRow(rowIndex);
            requestedRow = sheet.getRow(rowIndex);
        }
        return requestedRow
    }

    def getCell(row, columnIndex) {
        def requestedCell = row.getCell(columnIndex)
        if (requestedCell == null) {
            row.createCell(columnIndex)
            requestedCell = row.getCell(columnIndex)
        }
        return requestedCell
    }

    def createRowCell(row, columnIndex, value, style) {
        def requestedCell = getCell(row, columnIndex);
        requestedCell.setCellValue(value.toString())
        requestedCell.setCellStyle(style)
    }

    def setCell(sheet, rowIndex, columnIndex, value, style) {
        def requestedCell = getCell(getRow(sheet, rowIndex), columnIndex)
        requestedCell.setCellValue(value.toString())
        requestedCell.setCellStyle(style)
    }

}
