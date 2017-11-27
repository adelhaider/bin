#!/bin/sh

: "${FMW_HOME?Need to set FMW_HOME}"

GROOVY_CLASSPATH=$FMW_HOME/oep/common/modules/com.bea.common.configfwk_1.3.0.0.jar
GROOVY_CLASSPATH=$GROOVY_CLASSPATH:$FMW_HOME/wlserver/server/lib/weblogic.jar
GROOVY_CLASSPATH=$GROOVY_CLASSPATH:$FMW_HOME/osb/lib/modules/oracle.servicebus.kernel-api.jar
GROOVY_CLASSPATH=$GROOVY_CLASSPATH:$FMW_HOME/osb/lib/modules/oracle.servicebus.services.core.jar
GROOVY_CLASSPATH=$GROOVY_CLASSPATH:$FMW_HOME/osb/lib/modules/oracle.servicebus.resources.service.jar
GROOVY_CLASSPATH=$GROOVY_CLASSPATH:$FMW_HOME/osb/lib/modules/oracle.servicebus.kernel-wls.jar
GROOVY_CLASSPATH=$GROOVY_CLASSPATH:/home/adel/yodel/gitlab/integration/Groovy

#PROJECT_GIT_HOME=/home/adel/yodel/gitlab/integration/Groovy/*.groovy
#export PROJECT_GIT_HOME

#if [[ -d PROJECT_GIT_HOME ]]; then
#    GROOVY_CLASSPATH=$GROOVY_CLASSPATH:PROJECT_GIT_HOME
#fi

#if [[ -d $1 ]]; then
#    GROOVY_CLASSPATH=$GROOVY_CLASSPATH:$1
#fi

export GROOVY_CLASSPATH
#echo $GROOVY_CLASSPATH

groovy -cp $GROOVY_CLASSPATH GWLST.groovy
