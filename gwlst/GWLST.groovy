class Runner {
  static void main(String[] args) {
      def console = System.console()
      def gwlst = new GWLST()
      gwlst.welcome()
      def input = null
      def quit = false
      while (!quit) {
        if (console) {
            input = console.readLine("> Please enter command: ")
        } else {
            gwlst.msg "Cannot get System console."
            quit = true
            input = null
            break
        }
        if (input) {
          def inputTokens = input.tokenize()
          switch (inputTokens[0]) {
            case "usage":
              gwlst.usage()
              break
            case "help":
                gwlst.help inputTokens[1]
                break
            case "quit" : case "exit":
              gwlst.quit()
              quit = true
              break
            case "":
              gwlst.msg "Empty command not allowed. Please try again."
              break
            default:
              gwlst.execute(inputTokens[0],inputTokens[1])
              break
          }
        }
      }
  }
}

class GWLST {
  // define global variables
  def env
  def masterCommand
  def defaultPropertiesFile
  def properties
  WLSUtils WLS

  def GWLST() {
    // set up global variables
    env = System.getenv()
    masterCommand = new Command("master", "Top level command (i.e. GWLST)", { listSubcommands() }, null)
    defaultPropertiesFile = "../misc.properties"
    properties = new Properties()
    WLS = new WLSUtils()

    // set up general commands
    def initConnections = new Command("initConnections", "Initialize connections to server (i.e. Domain, Node Manager, Admin Server, OSB Server, JMS, JCA, etc.)", { initConnections() }, this)
    masterCommand.addSubcommand(initConnections)

    // set up domain commands
    def domain = new Command("domain", "Domain level commands", { listSubcommands() }, null)
    //domain.addSubcommands([])
    masterCommand.addSubcommand(domain)

    // set up node manager commands
    def connect = new Command("connect", "Connect to Node Manager", { nmConnect() }, this)
    def disconnect = new Command("disconnect", "Disconnect from Node Manager", { nmDisconnect() }, this)

    def nodemgr = new Command("nodemgr", "Node Manager commands", { listSubcommands() }, null)
    nodemgr.addSubcommands([connect,disconnect])
    masterCommand.addSubcommand(nodemgr)

    // set up admin server commands
    def admin = new Command("admin", "Admin Server commands", { listSubcommands() }, null)
    //admin.addSubcommands([])
    masterCommand.addSubcommand(admin)

    // set up osb server commands

    // set up jms server commands

    // set up jca adapter commands

    // set up data source commands
    def dataSource = new Command("ds", "Data Source commands", { listSubcommands() }, null)
    def isEnabled = new Command("isEnabled", "Check if datasource is enabled", { name -> isEnabled(name) }, this)
    dataSource.addSubcommands([isEnabled])
    masterCommand.addSubcommand(dataSource)

  }

  /**
    GWLST Commands
  */

  def welcome() {
    msg("Welcome to Groovy WLST (aka GWLST)")
    msg("Concatenate commands (with dot - '.') in a sequence to perform an action. Add arguments at the end of the sequence separated by space.\nType 'usage' or 'help' to get started.")
  }

  def usage() {
    masterCommand.listSubcommands()
  }

  def help(commandSequence) {
    if (!commandSequence) {
      usage()
      return
    }

    def command = findCommand(commandSequence)
    if (command != null)
      command.help()
    else
      msg("Command $commandSequence not found!")
  }

  def info(message) {
    msg(message)
  }

  def warn(message) {
    msg(message)
  }

  def err(message) {
    msg(message)
  }

  def msg(message) {
    msg(message,0)
  }

  def msg(message, level) {
      Character prefixChar = ' '

      if (level == 0) {
          println(message)
      } else {
        for (int i=0; i < level; i++) {
          print(prefixChar)
        }
        println(" $message")
      }
  }

  def loadDefaultProperties() {
    loadProperties(defaultPropertiesFile)

    /*File propertiesFile = new File(defaultPropertiesFile)
    propertiesFile.withInputStream {
        properties.load(it)
    }*/
  }

  def loadProperties(pathToFile) {
    File propertiesFile = new File(pathToFile)
    if (!propertiesFile.exists()) {
      msg("Properties file does not exists -- $pathToFile")
      return
    }

    propertiesFile.withInputStream {
        properties.load(it)
    }
  }

  def initConnections() {
    try {
        WLS.init("fusda12lv:7001", "weblogic", "DevTeam03", this)
    } catch (all) {
        msg("Failure in WLS.init due to ${all.getMessage()}")
    }
  }

  def findCommand(commandSequence) {
    if (!commandSequence) // i.e. command sequence is null or empty
      return null

    def commandTokens = commandSequence.tokenize('.')
    //msg(commandTokens)
    def iterator = commandTokens.iterator()
    def command = masterCommand.getSubcommand(iterator.next())

    //TODO optimize to return last found command in the sequence
    while (iterator.hasNext()) {
        if (command == null) {
            return null
        }
        command = command.getSubcommand(iterator.next())
    }

    if (command == null)
      return null
    else
      return command
  }

  def execute(commandSequence, args) {
    def command = findCommand(commandSequence)
    if (command != null)
      command.closure(args) //TODO: Surround with try..catch block
    else
      msg("Command $commandSequence not found!")
  }

  def quit() {
    msg("Closing connecting and quitting...")
    //TOOD
  }

  /**
    Node Manager Commands
  */

  def nmConnect() {
    msg("TODO")
  }

  def nmDisconnect() {
    msg("TODO")
  }

  /**
    Data Source Commands
  */

  def isEnabled(name) {
    if (!name) {
      msg("Please specify a name for the datasource.")
      return
    }
    WLSUtils.switchDatasourceEnablementIfRequired(name, true)
  }
}
