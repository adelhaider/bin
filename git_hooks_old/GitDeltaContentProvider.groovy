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
        println "Providing with files from Git diff ($oldrev to $newrev)"
        def diffProc = executeOnShell("git diff $oldrev $newrev --name-only")
        if (diffProc.exitValue() != 0) {
            println "Error listing the files changed as part of the push"
            println diffProc.text
            System.exit(diffProc.exitValue())
        }
        diffProc.text.split('\n').each { fileName ->
            if (fileName != null && fileName != "" && fileName.startsWith('OSB/Yodel_OSB')) {
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
            def showProc = executeOnShell("git show $toRev:$fullFileName")
            if (showProc.exitValue() != 0) {
                //failing to execute the command means that the file is not part of the latest commit (i.e. it apperas in the diff as a deletion)
                return nextFile()
            } else {
                return [
                     name: fileName
                   , path: filePath
                   , text: showProc.text
                   ]
            }
        } catch (EmptyStackException ese) {
            return null;
        }
    }

    private def executeOnShell(String command) {
        def pwd = new File(System.getenv()["PWD"])
        pwd = new File('/gitlab/git-data/repositories/spectrum-fusion/ci-poc.git')
        //println "SSH: $pwd :: $command"
        //def process = new ProcessBuilder(["bash", "-c", command]).directory(pwd).redirectErrorStream(true).start()
        def process = new ProcessBuilder(command.split(' ')).directory(pwd).redirectErrorStream(true).start()
        process.waitFor()
        return process
    }

}
