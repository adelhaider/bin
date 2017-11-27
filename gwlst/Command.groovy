class Command {
  def name
  def description
  def subCommands
  Closure closure

  def NO_SUBCOMMANDS = "No Subcommands!"

  Command (name, description, closure, delegate) {
    this.name = name
    this.description = description
    this.closure = closure

    if (delegate == null)
      delegate = this

    closure.delegate = delegate
    subCommands = new HashMap()
  }

  def help() {
    println("$name - $description. List of Subcommands")
    listSubcommands()
  }

  def addSubcommand(command) {
    subCommands.put(command.name,command)
  }

  def addSubcommands(commands) {
    commands.each { command ->
      addSubcommand(command)
    }
  }

  def getSubcommand(commandName) {
    subCommands.get(commandName)
  }

  def listSubcommands() {
    if (subCommands.isEmpty()) {
        println NO_SUBCOMMANDS
    } else {
      subCommands.each { command ->
        println command.key
      }
    }
  }
}
