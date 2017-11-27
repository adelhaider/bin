import java.util.Stack
import java.util.EmptyStackException

import static groovy.io.FileType.FILES

class GitDeltaContentProvider {

    def fileList = new Stack()
    def fromRev
    def toRev

    def GitDeltaContentProvider(oldrev, newrev) {
        fromRev = oldrev
        toRev = newrev
        if (fromRev == "0000000000000000000000000000000000000000") {
            def devLogProc = executeOnShell("git log dev -1 --pretty=format:%H")
            if (devLogProc.exitValue() != 0) {
                println "Error finding out the last commit in dev"
                System.exit(devLogProc.exitValue())
            }
            fromRev = devLogProc.text.trim()
        }
        println "Providing with files from Git diff ($fromRev to $toRev)"
        def diffProc = executeOnShell("git diff $fromRev $toRev --name-only --diff-filter=ACMRTUXB")
        if (diffProc.exitValue() != 0) {
            println "Error listing the files changed as part of the push"
            println diffProc.text
            System.exit(diffProc.exitValue())
        }
        diffProc.text.split('\n').each { fileName ->
            if (fileName != null && fileName != "" && (fileName.startsWith('OSB/Metadata') || fileName.startsWith('OSB/Yodel_OSB'))) {
                println "Adding file to list: ${fileName}"
                fileList.push(fileName)
            }
        }
    }

    def nextFile() {
        try {
            def fullFileName = fileList.pop()
            def lastSlashIndex = fullFileName.lastIndexOf('/')
            def filePath = fullFileName.substring(0, lastSlashIndex)
            def fileName = fullFileName.substring(lastSlashIndex + 1)
            //def showProc = executeOnShell("git show $toRev:$fullFileName")
            def showProc = executeOnShell("git cat-file -p \$(git ls-tree $toRev $fullFileName | cut -d \" \" -f 3 | cut -f 1)")
            if (showProc.exitValue() != 0) {
                //failing to execute the command means that the file is not part of the latest commit (i.e. it appears in the diff as a deletion)
                println "Failed to obtain file content. Proceeding with next file"
                println showProc.text
                return nextFile()
            } else {
                return [
                     name: fileName
                   , path: filePath
                   , text: showProc.text
                   ]
            }
        } catch (EmptyStackException ese) {
            println "Stack is empty"
            return null;
        }
    }

    private def executeOnShell(String command) {
        def pwd = new File(System.getenv()["PWD"])
        pwd = new File('/gitlab/git-data/repositories/spectrum-fusion/integration.git')
        //println "SSH: $pwd :: $command"
        def process = new ProcessBuilder(["bash", "-c", command]).directory(pwd).redirectErrorStream(true).start()
        //def process = new ProcessBuilder(command.split(' ')).directory(pwd).redirectErrorStream(true).start()
        process.waitFor()
        return process
    }

}
