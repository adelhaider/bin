======================
NodeManager Commands - http://docs.oracle.com/cloud/latest/as111170/WLSTG/manage_servers.htm#WLSTG169
======================

> Start/Stop NodeManager - http://docs.oracle.com/cloud/latest/as111170/WLSTC/reference.htm#WLSTC516
+ startNodeManager([verbose], [nmProperties])
- verbose - Optional. Boolean value specifying whether WLST starts Node Manager in verbose mode. This argument defaults to false, disabling verbose mode.
- nmProperties - Optional. Comma-separated list of Node Manager properties, specified as name-value pairs. Node Manager properties include, but are not limited to, the following: NodeManagerHome, ListenAddress, ListenPort, and PropertiesFile.
- example: startNodeManager(verbose='true', NodeManagerHome='c:/Oracle/Middleware/wlserver_10.3/common/nodemanager', ListenPort='6666', ListenAddress='myhost'))

+ stopNodeManager()

Connect as NodeManager - ??
nmConnect('username','password','nmHost','nmPort', 'domainName','domainDir','nmType')


nmStart - start a server (DON NOT USE, DOESN\'T WORK PROPERLY)
start

======================
AdminServer Commands - ???
======================

Connect to AdminServer
connect()

Start a server
start('serverName','Server')

Start a cluster
start('clusterName','Cluster')
