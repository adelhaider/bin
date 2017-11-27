import java.util.Stack
import java.util.EmptyStackException

import static groovy.io.FileType.FILES

class FileSystemContentProvider {

    def fileList = new Stack()
    def path

    def FileSystemContentProvider(systemPath) {
        this.path = systemPath
        println "Providing with files from local file system path ($systemPath)"
        def diffProc = executeOnShell("cd $path | find . -type f")
        if (diffProc.exitValue() != 0) {
            println "Error listing the files"
            println diffProc.text
            System.exit(diffProc.exitValue())
        }
        diffProc.text.split('\n').each { fileName ->
            if (fileName != null && fileName != "") {
                println "Adding file to list: ${fileName}"
                fileList.push(fileName)
            }
        }
    }

    def nextFile() {
        try {
            def fullFileName = fileList.pop()
            //def showProc = executeOnShell("git show $toRev:$fullFileName")
            def showProc = executeOnShell("cat $fullFileName")
            if (showProc.exitValue() != 0) {
                //failing to execute the command means that the file is not part of the latest commit (i.e. it appears in the diff as a deletion)
                println "Failed to obtain file content. Proceeding with next file"
                println showProc.text
                return nextFile()
            } else {
                def lastSlashIndex = fullFileName.lastIndexOf('/')
                def filePath = fullFileName.substring(0, lastSlashIndex)
                def fileName = fullFileName.substring(lastSlashIndex + 1)
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
        def pwd = new File(path)
        //pwd = new File('/gitlab/git-data/repositories/spectrum-fusion/integration.git')
        //println "SSH: $pwd :: $command"
        def process = new ProcessBuilder(["bash", "-c", command]).directory(pwd).redirectErrorStream(true).start()
        //def process = new ProcessBuilder(command.split(' ')).directory(pwd).redirectErrorStream(true).start()
        process.waitFor()
        return process
    }

}
