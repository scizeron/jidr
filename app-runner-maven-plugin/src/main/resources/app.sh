#!/bin/sh

# ----------------------------------------------------------------------------
# Application Batch script

# Required :
#   A JDK must be installed 
#
# Version : ${project.version}
# Build   : ${timestamp}
# ----------------------------------------------------------------------------

EXIT_OK=0
EXIT_KO=1
EXIT_APP_STOPPED=2

STATUS_RUNNING=0
STATUS_STOPPED=1
HEALTH_SLEEP_TIME_MAX_RETRIES=150
HEALTH_SLEEP_TIME_IN_SECONDS=2
STATUS_SLEEP_TIME_MAX_RETRIES=5
STATUS_SLEEP_TIME_IN_SECONDS=1

BASEDIR=`dirname $0`/..
BASEDIR=`(cd "$BASEDIR"; pwd)`

APPDIR=$BASEDIR/app
CFGDIR=$BASEDIR/conf
RUNDIR=$BASEDIR/run
LOCKFILE=$RUNDIR/app.lock
ARTIFACT_FILE=$CFGDIR/artifact.cfg
RUN_FILE=$CFGDIR/run.cfg

NODE_HOME=`(cd "$BASEDIR/../.."; pwd)`

GOAL_CONFIG=1
GOAL_STOP=1
GOAL_START=1
GOAL_STATUS=1
GOAL_RESTART=1
GOAL_PORT=1
GOAL_HCHECK=1
GOAL_MANAGEMENT=1
OPTION_CONSOLE=1
OPTION_DEBUG=1
OPTION_PRINT=1

# ----------------------------------------------------------------------------
# logMessage
# ----------------------------------------------------------------------------
function logMessage
{
 echo "[`date +'%H:%M:%S'`] ${1}"
}

# ----------------------------------------------------------------------------
# logError
# ----------------------------------------------------------------------------
function logError
{
 echo "[`date +'%H:%M:%S'`] ERROR : ${1}"
}

# ----------------------------------------------------------------------------
# usage
# ----------------------------------------------------------------------------
function usage
{
 echo "Usage:  $0 [<goal(s)>] [options]"
 echo "Goals:"
 echo "  start         : Start the application."
 echo "  stop          : Stop the application."
 echo "  status        : Get the application status."
 echo "  restart       : Stop and start the application."
 echo "  health        : Perform a health check request."
 echo "  management    : Perform a management request." 
 echo "  help          : Display usage."
 echo "Options:"
 echo "  -c, --console : With \"start\" goal, disable nohup (it can be useful when start problems occur)."
 echo "  -u, --uri     : With \"management\" goal, set the management relative uri (without the contextPath) : $0 management -u reload."
 echo "  -p, --print   : With \"management\" goal, print the output request : $0 management -u reload -p."  
 echo "  -d, --debug   : debug mode"
}

# ----------------------------------------------------------------------------
# pid
# ----------------------------------------------------------------------------
function pid
{
 PID=""

 if [ -f $LOCKFILE ]; then
  PID=`cat $LOCKFILE`
  if [ ! -z "$PID" ]; then
   if [ ! -d /proc/$PID ]; then
    PID=""
   fi
  fi
 fi
 
 if [ "X$PID" == "X" ]; then
  if [ -f $LOCKFILE ]; then
   # on n'a pas trouve de PID et le fichier est present, il faut le supprimer
   rm -R $RUNDIR 2> /dev/null
  else
   NETSTAT_RESULT=`netstat -an | grep ":${APP_LISTEN_PORT}" | grep "LISTEN" | wc -l`
   if [ $NETSTAT_RESULT -eq 1 ]; then
    # on recupere le process en ecoute
    PID=`/usr/sbin/lsof -ni tcp:${APP_LISTEN_PORT} | grep java | awk -F " " '{print $2;}'`
   fi
  fi
 fi
}

# ----------------------------------------------------------------------------
# start
# ----------------------------------------------------------------------------
function start
{
 status 
 VAR_STATUS=$?
 if [ $VAR_STATUS == $STATUS_STOPPED ]; then
  echo "--------------------------------------------------------------------------------"
  echo " - APP         : ${APP_FILENAME}"
  echo " - JAVA_HOME   : ${APP_JAVA_HOME}"
  echo " - JAVA_OPTS   : ${APP_JAVA_OPTS}"
  echo " - SERVER PORT : ${APP_LISTEN_PORT}"

  if [ ${APP_LISTEN_PORT} != ${APP_MANAGEMENT_PORT} ]; then
   echo " - ADMIN PORT  : ${APP_MANAGEMENT_PORT}"
  fi

  if [ ${#APP_MANAGEMENT_CONTEXT_PATH} -gt 2 ]; then
   echo " - ADMIN PATH  : ${APP_MANAGEMENT_CONTEXT_PATH}"
  fi

  if [ ! -z ${APP_PROG_ARGS} ]; then
   echo " - ADD ARGS    : ${APP_PROG_ARGS}" 
  fi 
  echo "--------------------------------------------------------------------------------"

  CMD_LINE="${APP_JAVA_HOME}/bin/java ${APP_JAVA_OPTS} -Dapp.id=${APP_ID} -Dnode.home=${NODE_HOME} -DLOG_FILE=${APP_LOG_FILE}"
  CMD_LINE="${CMD_LINE} -jar ${APPDIR}/${APP_FILENAME} server"
  CMD_LINE="${CMD_LINE} --spring.config.location=${CFGDIR}/application.yml"
  CMD_LINE="${CMD_LINE} --logging.config=${CFGDIR}/logback.xml"
  CMD_LINE="${CMD_LINE} --server.port=${APP_LISTEN_PORT}"
  
  if [ ${APP_LISTEN_PORT} -ne ${APP_MANAGEMENT_PORT} ]; then
   CMD_LINE="${CMD_LINE} --management.port=${APP_MANAGEMENT_PORT}"
  fi
    
  if [ ! -z ${APP_PROG_ARGS} ]; then
   CMD_LINE="${CMD_LINE} ${APP_PROG_ARGS}"
  fi

  logMessage "CMD_LINE: $CMD_LINE"
  
  rm -Rf $RUNDIR 2> /dev/null
  mkdir $RUNDIR
  
  if [ $OPTION_CONSOLE -eq 0 ]; then
   logMessage "console mode ..."
   `$CMD_LINE`
  else
   nohup $CMD_LINE 2>/dev/null 1>/dev/null &
   PID=`echo $!`
   echo $PID > $LOCKFILE
  fi
   
  logMessage "${APP_ID} is starting ..."
    
  STATUS_SLEEP_TIME_RETRY=0
  while [ $STATUS_SLEEP_TIME_RETRY -lt $STATUS_SLEEP_TIME_MAX_RETRIES ];do
   logMessage "wait for status response : ${STATUS_SLEEP_TIME_IN_SECONDS} s ..."
   sleep ${STATUS_SLEEP_TIME_IN_SECONDS}
   status
   VAR_STATUS=$?
   
   if [ $VAR_STATUS == $STATUS_RUNNING ]; then
    STATUS_SLEEP_TIME_RETRY=$STATUS_SLEEP_TIME_MAX_RETRIES
   else
    let STATUS_SLEEP_TIME_RETRY++;
   fi
  done
  
  if [ $VAR_STATUS == $STATUS_STOPPED ]; then
   logError "${APP_ID} is failed"
   exit $EXIT_KO
  fi

  echo -n "[`date +'%H:%M:%S'`] health check "
    
  # on ajoute le test de heath a la suite du start
  HEALTH_OK=1
  HEALTH_SLEEP_TIME_MAX_RETRY=0
  
  while [ $HEALTH_SLEEP_TIME_MAX_RETRY -lt $HEALTH_SLEEP_TIME_MAX_RETRIES ];do
   invokeManagementUri "health" ${HCHECK_URI}
   HEALTH_RESULT=$?

   if [ $HEALTH_RESULT -eq 0 ]; then
    HEALTH_SLEEP_TIME_MAX_RETRY=$HEALTH_SLEEP_TIME_MAX_RETRIES
    HEALTH_OK=0
   else
    status
    VAR_STATUS=$?
    if [ $VAR_STATUS == $STATUS_STOPPED ]; then
     # si entre temps, on a kille le process, on sort
     HEALTH_SLEEP_TIME_MAX_RETRY=$HEALTH_SLEEP_TIME_MAX_RETRIES
    else
     echo -n "."
     sleep ${HEALTH_SLEEP_TIME_IN_SECONDS}
     let HEALTH_SLEEP_TIME_MAX_RETRY++;
    fi
   fi
  done
  
  echo ""
  
  if [ $HEALTH_OK -eq 0 ]; then
   logMessage "${APP_ID} health check is ok."
   showStatus
  else
    logError "${APP_ID} health check is ko."
    showStatus
    exit $EXIT_KO
  fi
  
 else
  logMessage "${APP_ID} is already running ($PID)."
 fi
}

# ----------------------------------------------------------------------------
# status
# ----------------------------------------------------------------------------
function status
{
 pid
  
 if [ "X$PID" == "X" ]; then
  return $STATUS_STOPPED
 else
  return $STATUS_RUNNING
 fi 
}

# ----------------------------------------------------------------------------
# showStatus
# ----------------------------------------------------------------------------
function showStatus
{
 status
 VAR_STATUS=$?

 if [ ${VAR_STATUS} -eq ${STATUS_RUNNING} ]; then
  logMessage "${APP_ID} is running ($PID)."
 else
  logMessage "${APP_ID} is shutdown."
 fi
 
 return $VAR_STATUS
}

# ----------------------------------------------------------------------------
# invokeManagementUri
# $1 command name
# $2 command uri
# $3 logMessage 0/1 (facultatif)
# ----------------------------------------------------------------------------
function invokeManagementUri
{
 LOG_MSG=${3:-1}
 pid
  
 if [ "X$PID" == "X" ]; then
  logError "$1 ko, ${APP_ID} is shutdown."
  exit $EXIT_APP_STOPPED
 fi

 REQUEST_URL="http://localhost:${APP_MANAGEMENT_PORT}$2"
  
 if [ $LOG_MSG -eq 0 ]; then
  logMessage "GET $REQUEST_URL"
 fi
  
 wget --ignore-length --no-verbose --no-proxy ${REQUEST_URL} -O ${RUNDIR}/output 2> ${RUNDIR}/output_error
 RESULT=$?
 
 RESULT_CODE=$EXIT_OK
 OUTPUT_FILE=${RUNDIR}/output
 
 if [ $RESULT -ne 0 ]; then
  RESULT_CODE=$EXIT_KO
  if [ $LOG_MSG -eq 0 ]; then
   CONTENT=`cat ${RUNDIR}/output_error`
   echo "${CONTENT}"
  fi
 else
  if [ $LOG_MSG -eq 0 ] && [ $OPTION_PRINT -eq 0 ] ; then
   CONTENT=`cat $OUTPUT_FILE`
   echo "${CONTENT}"
  fi
 
 fi
 
 rm ${RUNDIR}/output*
 return $RESULT_CODE
}

# ----------------------------------------------------------------------------
# stop
# ----------------------------------------------------------------------------
function stop
{
 status
 VAR_STATUS=$?
 if [ $VAR_STATUS == $STATUS_RUNNING ]; then
  pid
  kill -15 $PID
  logMessage "${APP_ID} is stopping ..."
  
  STATUS_SLEEP_TIME_RETRY=0
  
  while [ $STATUS_SLEEP_TIME_RETRY -lt $STATUS_SLEEP_TIME_MAX_RETRIES ];do
   logMessage "wait for status response : ${STATUS_SLEEP_TIME_IN_SECONDS} s ..."
   sleep ${STATUS_SLEEP_TIME_IN_SECONDS}
   status
   VAR_STATUS=$?
   if [ $VAR_STATUS == $STATUS_RUNNING ]; then
    let STATUS_SLEEP_TIME_RETRY++;
   else
    break
   fi
  done
  
  if [ $VAR_STATUS == $STATUS_RUNNING ]; then
   logMessage "Force shutdown."
   kill -9 $PID
  fi  

  rm -R $RUNDIR 2> /dev/null
 
 fi
 
 logMessage "${APP_ID} is stopped."
}

# ----------------------------------------------------------------------------
# transformYaml
# ----------------------------------------------------------------------------
function transformYaml 
{
 local prefix=$2
 local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
 sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=%s\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

# ----------------------------------------------------------------------------
# parseYaml
# ----------------------------------------------------------------------------
function parseYaml
{
 echo -n "$1" | grep "$2" | awk -F "=" '{print $2;}' | tr -d '\r'  | tr -d '\n'
}

# ----------------------------------------------------------------------------
# initConfiguration
# ----------------------------------------------------------------------------
function initConfiguration
{
 # les ports peuvent etre positionnes dans run.cfg durant l'install
 # si c'est le cas, ils surchargent les valeurs presentes dans le fichier application.yml
 # sinon, on extrait les valeurs des ports dans le fichier application.yml car on a notamment besoin de l'admin port pour invoquer /health 

 APPLICATION_YML=`transformYaml ${CFGDIR}/application.yml`

 if [ -z $APP_LISTEN_PORT ]; then
  APP_LISTEN_PORT=`parseYaml "$APPLICATION_YML" "server_port"`
 fi

 if [ -z $APP_MANAGEMENT_PORT ]; then
  APP_MANAGEMENT_PORT=`parseYaml "$APPLICATION_YML" "management_port"`
  if [ -z $APP_MANAGEMENT_PORT ]; then
   APP_MANAGEMENT_PORT=$APP_LISTEN_PORT
  fi
 fi

 APP_MANAGEMENT_CONTEXT_PATH=`parseYaml "$APPLICATION_YML" "management_contextPath"`
 if [ -z $APP_MANAGEMENT_CONTEXT_PATH ]; then
  APP_MANAGEMENT_CONTEXT_PATH="/"
 fi
 
 HCHECK_URI=${APP_MANAGEMENT_CONTEXT_PATH}${HCHECK_URI:-/health}
 RELOAD_CONFIG_URI=${APP_MANAGEMENT_CONTEXT_PATH}${RELOAD_CONFIG_URI:-/reload}

 APP_ID="${APP_ARTIFACT}_$(hostname)_${APP_LISTEN_PORT}"
 APP_FILENAME="${APP_ARTIFACT}-${APP_VERSION}.${APP_PACKAGING}"
 APP_LOG_FILE="${APP_LOG_PATH:-/tmp}/${APP_ID}.log"

 if [ $OPTION_DEBUG -eq 0 ]; then
  echo " ************** DEBUG CONFIG INFO **************"
  echo " - APP_LISTEN_PORT             : $APP_LISTEN_PORT]"
  echo " - APP_MANAGEMENT_PORT         : $APP_MANAGEMENT_PORT]"
  echo " - APP_MANAGEMENT_CONTEXT_PATH : $APP_MANAGEMENT_CONTEXT_PATH]"
  echo " - HCHECK_URI                  : $HCHECK_URI]"
  echo " - RELOAD_CONFIG_URI           : $RELOAD_CONFIG_URI]"
  echo " - APP_FILENAME                : $APP_FILENAME"
  echo " - APP_ID                      : $APP_ID"    
  echo " - APP_LOG_FILE                : $APP_LOG_FILE" 
  echo " ***********************************************"
 fi
}

# ----------------------------------------------------------------------------
# convertWindowsFile
# ----------------------------------------------------------------------------
function convertWindowsFile
{
 if [ -f ${1} ] ; then
  mv ${1} ${1}_tmp
  awk '{ sub("\r$", ""); print }' ${1}_tmp > ${1}
  rm ${1}_tmp
 else 
  logError "${1} is missing"
  exit $EXIT_KO
 fi
}

# ----------------------------------------------------------------------------
# loadConfigurationFiles
# ----------------------------------------------------------------------------
function loadConfigurationFiles
{
 convertWindowsFile $ARTIFACT_FILE
 convertWindowsFile $RUN_FILE
 convertWindowsFile ${CFGDIR}/application.yml
}

# ----------------------------------------------------------------------------
# main
# ----------------------------------------------------------------------------
loadConfigurationFiles

. $ARTIFACT_FILE
. $RUN_FILE

if [ $# -eq 0 ]; then
 usage
 exit $EXIT_KO
fi

while [ $# != 0 ]
 do case $1 in
  -h | --help | help) 
   usage
   exit $EXIT_OK
   ;;
  -d | --debug) 
   OPTION_DEBUG=0
   shift
   ;;  
  -c | --console) 
   OPTION_CONSOLE=0
   shift
   ;;
  -p | --print) 
   OPTION_PRINT=0
   shift
   ;;   
  -u | --uri) 
   shift
   if [ -z $1 ]; then
    logError "The relative management uri is missing."
    exit $EXIT_KO 
   fi
   MANAGEMENT_URI=$1
   shift
   ;;
  config)
   GOAL_CONFIG=0
   shift
   ;;
  start) 
   GOAL_START=0
   shift
   ;;
  stop)
   GOAL_STOP=0
   shift
   ;;
  restart)
   GOAL_RESTART=0 
   shift
   ;;		
  management)
   GOAL_MANAGEMENT=0 
   shift
   ;;		   
  status)
   GOAL_STATUS=0
   shift
   ;; 
  health)   
   GOAL_HCHECK=0
   shift
   ;;     
  *) 
   logError "Unknown parameter : $1"
   usage
   exit $EXIT_KO
   ;;		
 esac
done

initConfiguration

if [ $GOAL_RESTART -eq 0 ]; then
 GOAL_STOP=1
 GOAL_START=1
fi

if [ $GOAL_STOP -eq 0 ]; then
 status
 VAR_STATUS=$?
 if [ $VAR_STATUS == $STATUS_RUNNING ]; then
  showStatus
  stop
 else
  logMessage "${APP_ID} is already stopped."
 fi
fi

if [ $GOAL_START -eq 0 ]; then
 start
fi

if [ $GOAL_RESTART -eq 0 ]; then
 status
 VAR_STATUS=$?
 if [ $VAR_STATUS == $STATUS_RUNNING ]; then
  showStatus
  stop
 fi  
 start
fi

if [ $GOAL_STATUS -eq 0 ]; then
 showStatus
 VAR_STATUS=$?
 if [ $VAR_STATUS == $STATUS_RUNNING ]; then
  exit $EXIT_OK
 else
  exit $EXIT_APP_STOPPED
 fi
fi

if [ $GOAL_CONFIG -eq 0 ]; then
 OPTION_PRINT=0
 invokeManagementUri "config" "${RELOAD_CONFIG_URI}" 0
 exit $?
fi

if [ $GOAL_HCHECK -eq 0 ]; then
 invokeManagementUri "health" "${HCHECK_URI}" 0
 exit $?
fi

if [ $GOAL_MANAGEMENT -eq 0 ]; then

 if [ -z ${MANAGEMENT_URI} ]; then
  logError "The relative management uri is missing."
  exit $EXIT_KO
 fi

 echo ${MANAGEMENT_URI} | grep -e '^/' > /dev/null
 if [ $? -eq 0 ]; then
  MANAGEMENT_REQUEST_URI="${APP_MANAGEMENT_CONTEXT_PATH}${MANAGEMENT_URI}" 
 else
  MANAGEMENT_REQUEST_URI="${APP_MANAGEMENT_CONTEXT_PATH}/${MANAGEMENT_URI}"
 fi
 
 invokeManagementUri "request" "${MANAGEMENT_REQUEST_URI}" 0
 exit $?
fi
