import java.io.*

workspacePath = 'OSB/Yodel_OSB'
folderIgnoreList = ["src", "System", ".adf", ".settings", ".data"]

def executeOnShell(command) {
    //println "SSH: $command"
    def pwd = new File(System.getenv()["PWD"])
    pwd = new File('/gitlab/git-data/repositories/spectrum-fusion/integration.git')
    def process = new ProcessBuilder(command.split(' ')).directory(pwd).redirectErrorStream(true).start()
    process.waitFor()
    return process
}

def fileExistsInGit(filepath) {
    return executeOnShell("git cat-file -e ${newrev}:${filepath}").exitValue() == 0
}

def validateArtifactConfigFileForEnvironment(groupId, artifactId, environment) {
    envConfigPath = "Deployment/config/${environment}/OSB_customization"
//    println "checking existence of ${environment} OSB customization file (${envConfigPath}/${groupId}/${artifactId}[_soa1|_soa2|_soa3].xml)"
    if (fileExistsInGit("${envConfigPath}/${groupId}/${artifactId}.xml")) {
        return true
    } else {
        domain1FileExists = fileExistsInGit("${envConfigPath}/${groupId}/${artifactId}_soa1.xml")
        domain2FileExists = fileExistsInGit("${envConfigPath}/${groupId}/${artifactId}_soa2.xml")
        domain3FileExists = fileExistsInGit("${envConfigPath}/${groupId}/${artifactId}_soa3.xml")
        if (!domain1FileExists && !domain2FileExists && !domain3FileExists) {
            println "ERROR: Customization file for ${environment} environment NOT found for artifact ${artifactId}"
            return false
        } else {
            return true
        }
    }
}

def validateArtifactFiles(impactedArtifactCoordinate) {
    def impactedArtifactCoordinateParts = impactedArtifactCoordinate.split('-')
    def groupId = impactedArtifactCoordinateParts[0]
    def artifactId = impactedArtifactCoordinateParts[1]
    
    def devIsOk = validateArtifactConfigFileForEnvironment(groupId, artifactId, 'dev')
    def stIsOk = validateArtifactConfigFileForEnvironment(groupId, artifactId, 'st')
    def ciIsOk = validateArtifactConfigFileForEnvironment(groupId, artifactId, 'ci')
    def pomFileIsOk = fileExistsInGit("OSB/Metadata/Maven/${groupId}/${artifactId}.pom")
    if (!pomFileIsOk) {
        println "ERROR: POM file NOT found for artifact ${artifactId}"
    }
    def unitTestIsOk = (groupId == "Common")? true : fileExistsInGit("OSB/Testing/${groupId}/${artifactId}.xml")
    if (!unitTestIsOk) {
        println "ERROR: SoapUI project file NOT found for artifact ${artifactId}"
    }
    return devIsOk && stIsOk && ciIsOk && unitTestIsOk && pomFileIsOk
}

def deriveArtifactsToReleaseFromGitDiff() {
    def amendedArtifactsCoordinates = []
    def diffProc = executeOnShell("git diff ${oldrev} ${newrev} --name-only --diff-filter=ACMRTUXB")
    if (diffProc.exitValue() != 0) {
        println "Error comparing start and end commits"
        System.exit(diffProc.exitValue())
    }
    def changedFileList = diffProc.text
    //println "changedFileList = ${changedFileList}"
    changedFileList.eachLine { changedFileName ->
        if (changedFileName.startsWith("OSB/Yodel_OSB")) {
            //println "Processing line: ${changedFileName}"

            def artifactGroupName = null
            def artifactName = null
            def artifactVersion = null
            def serviceType = null

            changedFileNameParts = changedFileName.split("/")
            if (changedFileNameParts.length < 5) {
                //e.g. OSB/Yodel_OSB/pom.xml
                //println "Ignoring changes to workspace/project level file. File: ${changedFileName}"
            } else {
                def sbProjectName = changedFileNameParts[2]
                if (sbProjectName in folderIgnoreList) {
                    //e.g. OSB/Yodel_OSB/System/pom.xml
                    //println "Ignoring changes to ${sbProjectName} folder as it is in the ignore list"
                } else {
                    //e.g. OSB/Yodel_OSB/Common_CanonicalDataModel/v1/Parcel.xsd
                    //e.g. OSB/Yodel_OSB/Common_Resources/v2/templates/synchServiceTemplate.ptx
                    if (changedFileNameParts[3] in folderIgnoreList) {
                        //println "Ignoring changes to ${changedFileNameParts[3]} folder as it is in the ignore list"
                    } else {
                        if (sbProjectName.startsWith("Common_")) {
                            artifactGroupName = "Common"
                            artifactName = sbProjectName.split("_")[1]
                            artifactVersion = changedFileNameParts[3]
                            serviceType = ""
                        } else {
                            artifactGroupName = sbProjectName
                            serviceType = changedFileNameParts[3]
                            if (serviceType == "common") {
                                //e.g. OSB/Yodel_OSB/QueryServices/common/v1/xsd/QueryServicesCommon.xsd
                                artifactName = 'common'
                                artifactVersion = changedFileNameParts[4]
                            } else {
                                //e.g. OSB/Yodel_OSB/QueryServices/data/User/v1/xsd/Parcel.xsd
                                artifactName = changedFileNameParts[4]
                                artifactVersion = changedFileNameParts[5]
                            }
                        }
                        artifactCoordinates = "${artifactGroupName}-${artifactName}_${artifactVersion}".toString()
                        if (serviceType != "common") {
                            amendedArtifactsCoordinates << artifactCoordinates
                        }
                    }
                }
            }
        }
    }
    
    amendedArtifactsCoordinates.unique()
    
    return amendedArtifactsCoordinates
}


oldrev = args[0]
newrev = args[1]

def impactedArtifactCoordinates = deriveArtifactsToReleaseFromGitDiff()

println "List of changed artifacts: ${impactedArtifactCoordinates}"
def allGood = true
for (impactedArtifactCoordinate in impactedArtifactCoordinates) {
    println "Validating $impactedArtifactCoordinate"
    def isThisArtifactAlright = validateArtifactFiles(impactedArtifactCoordinate)
    allGood = allGood && isThisArtifactAlright
}
if (!allGood) {
    println "Files are missing for the artifacts pushed. Please fix and try again"
    System.exit(1)
}

