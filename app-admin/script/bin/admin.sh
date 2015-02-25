#!/bin/sh

# ----------------------------------------------------------------------------
# Application Admin Batch script
#
# Version : ${project.version}
# Build   : ${timestamp}
# ----------------------------------------------------------------------------

EXIT_OK=0
EXIT_KO=1

BASEDIR=`dirname $0`/..
BASEDIR=`(cd "$BASEDIR"; pwd)`

VERSIONS_DIR=$BASEDIR/versions
WORK_DIR=$BASEDIR/work
UNZIP_DIR=${WORK_DIR}/inprogress
TIMESTAMP=`date +'%Y%m%d%H%M%S'`

APP_ARTIFACT_PACKAGING=zip
CONF_ARTIFACT_PACKAGING=zip

CMD_CONFIG=1
CMD_STOP=1
CMD_START=1
CMD_STATUS=1
CMD_RESTART=1
CMD_ROLLBACK=1
CMD_DEPLOY=1
CMD_INSTALL=1
CMD_VERSION=1
CMD_HCHECK=1
CMD_CLEAN=1
CMD_MANAGEMENT=1

OPTION_PRINT=1

# ----------------------------------------------------------------------------
# usage
# ----------------------------------------------------------------------------
function usage
{
 echo ""
 echo "Usage:  $0 [<subcommand>] [options] args"
 echo ""
 echo "Subcommand:"
 echo "  install   : Install a new configurable application."
 echo "  deploy    : Deploy the current application (previously installed)." 
 echo "  rollback  : Rollback the current application and restart the previous."
 echo "  config    : Update the current configuration application."
 echo "  start     : Start the current application."
 echo "  stop      : Stop the current application."
 echo "  restart   : ReStart the current application."
 echo "  status    : Get the current application status."
 echo "  health    : Perform a health check request."
 echo "  clean     : Clean old version sub directories." 
 echo "  version   : Display the current version."
 echo "  management: Invoke a management request."
 echo "  help      : Display usage."
 
 echo ""
 echo "Options:"
 echo "  -nu       : Nexus search Url."
 echo "  -rn       : Release repository Name." 
 echo "  -sn       : Snapshot repository Name."
 echo "  -ag       : Application GroupId."
 echo "  -aa       : Application ArtifactId."
 echo "  -av       : Application Version."
 echo "  -ap       : Application Packaging."
 echo "  -ac       : Application Classifier."
 echo "  -cg       : Configuration GroupId."
 echo "  -ca       : Configuration ArtifactId."
 echo "  -cv       : Configuration Version."
 echo "  -cp       : Configuration Packaging."
 echo "  -cc       : Configuration Classifier."
 echo "  -u        : With \"management\" subcommand, set the management relative uri (without the contextPath) : $0 management -u reload."
 echo "  -p        : With \"management\" subcommand, print the output request : $0 management -u reload -p."   
 echo "  -f        : Force the installation when a RELEASE version is already present."
 
 echo ""
 echo "Examples:"
 echo " $0 install -ag <APP_GROUP> -ai <APP_ID> -av <APP_VERSION> -ac <APP_CLASSIFIER> \
 -cg <CONF_GROUP> -ci <CONF_ID> -cv <CONF_VERSION> -cc <CONF_CLASSIFIER> \
 -nu <NEXUS_SEARCH_URL> -rn <RELEASE_REPOSITORY_NAME> -sn <SNAPSHOT_REPOSITORY_NAME> [parameter=value]"
 echo ""
 echo " $0 deploy"
 echo "" 
 echo " $0 rollback"
 echo "" 
 echo " $0 config -cg <CONF_GROUP> -ci <CONF_ID> -cv <CONF_VERSION> -cc <CONF_CLASSIFIER> \
 -nu <NEXUS_SEARCH_URL> -rn <RELEASE_REPOSITORY_NAME> -sn <SNAPSHOT_REPOSITORY_NAME>"
 echo "" 
 echo " $0 start"
 echo ""  
 echo " $0 stop"
 echo ""
 echo " $0 restart"
 echo ""
 echo " $0 status"
 echo "" 
 echo " $0 health"
 echo "" 
 echo " $0 clean" 
}

# ----------------------------------------------------------------------------
# logMessage
# ----------------------------------------------------------------------------
function logMessage
{
 echo "[`date +'%H:%M:%S'`] $1"
}

# ----------------------------------------------------------------------------
# logError
# ----------------------------------------------------------------------------
function logError
{
 echo "[`date +'%H:%M:%S'`] ERROR : $1"
}

# ----------------------------------------------------------------------------
# failOnError
# ----------------------------------------------------------------------------
function failOnError
{
 RESULT=$1
 if [ $RESULT -ne 0 ]; then
  if [ $# -eq 2 ]; then
   logError "$2"
  fi
  exit $EXIT_KO
 fi
}

# ----------------------------------------------------------------------------
# download
# ----------------------------------------------------------------------------
function download
{
 logMessage "Download with $# arg(s) : \"$*\""
 
 ARTIFACT_GROUP=$1
 ARTIFACT_ID=$2
 ARTIFACT_VERSION=$3
 ARTIFACT_PACKAGING=$4
 
 # le classifier est facultatif
 if [ $# -eq 5 ]; then
  ARTIFACT_CLASSIFIER=$5
 else
  ARTIFACT_CLASSIFIER=""
 fi
 
 ARTIFACT_SNAPSHOT=`echo ${ARTIFACT_VERSION} | grep SNAPSHOT`
 
 if [ "${ARTIFACT_SNAPSHOT}" == "${ARTIFACT_VERSION}" ]; then
  REPO_NAME=${SNAPSHOT_REPOSITORY_NAME}
 else
  REPO_NAME=${RELEASE_REPOSITORY_NAME}
 fi 
 
 DOWNLOAD_ARTIFACT_URL="${NEXUS_SEARCH_URL}?r=${REPO_NAME}&g=${ARTIFACT_GROUP}&a=${ARTIFACT_ID}&v=${ARTIFACT_VERSION}&e=${ARTIFACT_PACKAGING}"
 ARTIFACT="${ARTIFACT_GROUP}:${ARTIFACT_ID}:${ARTIFACT_PACKAGING}:${ARTIFACT_VERSION}"
 
 if [ "X${ARTIFACT_CLASSIFIER}" != "X" ]; then
  ARTIFACT_FILENAME="${ARTIFACT_ID}-${ARTIFACT_VERSION}-${ARTIFACT_CLASSIFIER}.${ARTIFACT_PACKAGING}"
  ARTIFACT="${ARTIFACT}:${ARTIFACT_CLASSIFIER}"
  DOWNLOAD_ARTIFACT_URL="${DOWNLOAD_ARTIFACT_URL}&c=${ARTIFACT_CLASSIFIER}"
 else
  ARTIFACT_FILENAME="${ARTIFACT_ID}-${ARTIFACT_VERSION}.${ARTIFACT_PACKAGING}"
 fi
 
 logMessage "Artifact: ${ARTIFACT} on ${REPO_NAME}."
 logMessage "Download ${DOWNLOAD_ARTIFACT_URL} to ${WORK_DIR}/${ARTIFACT_FILENAME} ..."
 wget --no-proxy ${DOWNLOAD_ARTIFACT_URL} -q -O ${WORK_DIR}/${ARTIFACT_FILENAME}
 RESULT=$?
 logMessage "Result : $RESULT"
 
 if [ $RESULT -ne 0 ]; then
  logError "Download error."
  exit $EXIT_KO
 fi
 
 if [ ! -s ${WORK_DIR}/${ARTIFACT_FILENAME} ]; then
   logError "${WORK_DIR}/${ARTIFACT_FILENAME} is empty."
   exit $EXIT_KO
 fi
     
 logMessage "${WORK_DIR}/${ARTIFACT_FILENAME} OK."
 DOWNLOADED_ARTIFACT_URL=${ARTIFACT_FILENAME}
}

# ----------------------------------------------------------------------------
# currentVersion
# ----------------------------------------------------------------------------
function currentVersion
{
 CURRENT_VERSION=`readlink ${VERSIONS_DIR}/current`
 if [ -z ${CURRENT_VERSION} ]; then
  if [ "$1" == "exit" ]; then
   logError "No current version."
   exit $EXIT_KO
  #else
  # logMessage "No current version."
  fi
 else
  CURRENT_VERSION=`echo $CURRENT_VERSION | awk -F "/" '{print $NF}'`
  #logMessage "Current version is ${CURRENT_VERSION}."
 fi
}

# ----------------------------------------------------------------------------
# currentVersionAndDisplay
# ----------------------------------------------------------------------------
function currentVersionAndDisplay
{
 currentVersion
 if [ ! -z $CURRENT_VERSION ]; then
  logMessage "Current version is \"${CURRENT_VERSION}\"."
 else
  logMessage "No current version."
 fi
}

# ----------------------------------------------------------------------------
# currentVersionAndExit
# ---------------------------------------------------------------------------
function currentVersionAndExit
{
 currentVersion "exit"
}

# ----------------------------------------------------------------------------
# admin
# ----------------------------------------------------------------------------
function invokeAppCmd
{
 VERSION=$1
 APP_HOME=${VERSIONS_DIR}/${VERSION}
 SCRIPT=$2
 GOAL=$3
 ARGS=$4

 logMessage "Run ${APP_HOME}/bin/${SCRIPT} ${GOAL} ${ARGS}"
 
 ${APP_HOME}/bin/${SCRIPT} ${GOAL} ${ARGS}
 RESULT=$?
 
 if [ $RESULT -eq 0 ]; then
  logMessage "The admin command \"${GOAL}\" is ok."
 else
  if [ "${GOAL}" == "status" ]; then
   if [ $RESULT -eq 2 ]; then
    logMessage "The command \"${GOAL}\" is ok. The application is shutdown."
    RESULT=1
   else
    if [ $RESULT -ne 1 ]; then
     logError "The command \"${GOAL}\" has failed with code $RESULT."
     RESULT=1
    else
     logError "The command \"${GOAL}\" has failed."
    fi
   fi
  else
   logError "The command \"${GOAL}\" has failed."
  fi
 fi
 return $RESULT 
}

# ----------------------------------------------------------------------------
# invokeCurrentAppCmd
# ----------------------------------------------------------------------------
function invokeCurrentAppCmd
{
 SCRIPT="app.sh"
 GOAL=$1
 ARGS=${2:-""}
 currentVersionAndExit
 invokeAppCmd ${CURRENT_VERSION} ${SCRIPT} ${GOAL} "${ARGS}"
 return $?
}

# ----------------------------------------------------------------------------
# start
# ----------------------------------------------------------------------------
function start
{
 invokeCurrentAppCmd "start"
 return $?
}

# ----------------------------------------------------------------------------
# stop
# ----------------------------------------------------------------------------
function stop
{
 invokeCurrentAppCmd "stop"
 return $?
}

# ----------------------------------------------------------------------------
# status
# ----------------------------------------------------------------------------
function status
{
 invokeCurrentAppCmd "status"
 return $?
}

# ----------------------------------------------------------------------------
# restart
# ----------------------------------------------------------------------------
function restart
{
 invokeCurrentAppCmd "restart"
 return $?
}

# ----------------------------------------------------------------------------
# healthCheck
# ----------------------------------------------------------------------------
function healthCheck
{
 logMessage "- health check"
 invokeCurrentAppCmd "health"
 return $?
}

# ----------------------------------------------------------------------------
# management
# ----------------------------------------------------------------------------
function management
{
 logMessage "- management"
 ARGS="${MANAGEMENT_URI}" 
 if [ $OPTION_PRINT -eq 0 ] ; then
  ARGS="${ARGS} -p"
 fi
 
 invokeCurrentAppCmd "management" "${ARGS}"
 return $?
}

# ----------------------------------------------------------------------------
# update run.cfg file
# ----------------------------------------------------------------------------
function updateRunCfgFile
{
 RUN_CFG_FILE=$1
 APP_LISTEN_PORT=$2
 APP_MANAGEMENT_PORT=$3
 echo "" 1>> ${RUN_CFG_FILE}
 echo "# append server and management ports (install command)" 1>> ${RUN_CFG_FILE}
 echo "APP_LISTEN_PORT=${APP_LISTEN_PORT}" 1>> ${RUN_CFG_FILE}
 echo "APP_MANAGEMENT_PORT=${APP_MANAGEMENT_PORT}" 1>> ${RUN_CFG_FILE}
 echo "" 1>> ${RUN_CFG_FILE}
 logMessage "The ${RUN_CFG_FILE} is appended."
}

# ----------------------------------------------------------------------------
# config
# ----------------------------------------------------------------------------
function config
{
 currentVersionAndExit
 
 mkdir -p ${WORK_DIR}
 mkdir -p ${UNZIP_DIR}
 
 # download conf
 if [ ! -z $CONF_ARTIFACT_CLASSIFIER ] ; then
 	download ${CONF_ARTIFACT_GROUP} ${CONF_ARTIFACT_ID} ${CONF_ARTIFACT_VERSION} ${CONF_ARTIFACT_PACKAGING} ${CONF_ARTIFACT_CLASSIFIER}
 else
  download ${CONF_ARTIFACT_GROUP} ${CONF_ARTIFACT_ID} ${CONF_ARTIFACT_VERSION} ${CONF_ARTIFACT_PACKAGING}
 fi
 
 CONF_ARTIFACT_FILENAME=${DOWNLOADED_ARTIFACT_URL}

 logMessage "Unzip ${CONF_ARTIFACT_FILENAME}."
 
 rm -R ${VERSIONS_DIR}/${CURRENT_VERSION}/conf_new 2> /dev/null
 unzip -q ${WORK_DIR}/${CONF_ARTIFACT_FILENAME} -d ${VERSIONS_DIR}/${CURRENT_VERSION}/conf_new
 
 # le fichier artifact.cfg provient de l'applicatif
 # en cas de reconfiguration, le fichier ne sera pas presnt
 # on doit le recopier avant de supprimer le repertoire
 cp ${VERSIONS_DIR}/${CURRENT_VERSION}/conf/artifact.cfg ${VERSIONS_DIR}/${CURRENT_VERSION}/conf_new/
 
 # le fichier run.cfg contient des valeurs issues de l'install
 # en cas de reconfiguration, les valeurs seront perdus
 
 APP_LISTEN_PORT=`cat ${VERSIONS_DIR}/${CURRENT_VERSION}/conf/run.cfg | grep "APP_LISTEN_PORT" | cut -d "=" -f 2`
 APP_MANAGEMENT_PORT=`cat ${VERSIONS_DIR}/${CURRENT_VERSION}/conf/run.cfg | grep "APP_MANAGEMENT_PORT" | cut -d "=" -f 2`
 
 if [ ! -z $APP_LISTEN_PORT ]; then
  updateRunCfgFile ${VERSIONS_DIR}/${CURRENT_VERSION}/conf_new/run.cfg $APP_LISTEN_PORT $APP_MANAGEMENT_PORT
 fi
 
 rm -R ${VERSIONS_DIR}/${CURRENT_VERSION}/conf
 mv ${VERSIONS_DIR}/${CURRENT_VERSION}/conf_new ${VERSIONS_DIR}/${CURRENT_VERSION}/conf
 logMessage "The \"${VERSIONS_DIR}/${CURRENT_VERSION}/conf\" is updated."
 
 rm -R ${WORK_DIR}
 
 invokeCurrentAppCmd config
 return $? 
}

# ----------------------------------------------------------------------------
# install
# ----------------------------------------------------------------------------
function install
{
 logMessage "- install"
 
 echo ${APP_ARTIFACT_VERSION} | grep SNAPSHOT > /dev/null
 APP_ARTIFACT_SNAPSHOT=$?
 
 mkdir -p ${WORK_DIR}
 mkdir -p ${UNZIP_DIR}
 
 # download app
 download $APP_ARTIFACT_GROUP $APP_ARTIFACT_ID $APP_ARTIFACT_VERSION $APP_ARTIFACT_PACKAGING $APP_ARTIFACT_CLASSIFIER
 APP_ARTIFACT_FILENAME=${DOWNLOADED_ARTIFACT_URL}

 # download conf
 if [ ! -z $CONF_ARTIFACT_CLASSIFIER ] ; then
  download $CONF_ARTIFACT_GROUP $CONF_ARTIFACT_ID $CONF_ARTIFACT_VERSION $CONF_ARTIFACT_PACKAGING $CONF_ARTIFACT_CLASSIFIER
 else
  download $CONF_ARTIFACT_GROUP $CONF_ARTIFACT_ID $CONF_ARTIFACT_VERSION $CONF_ARTIFACT_PACKAGING
 fi
 
 CONF_ARTIFACT_FILENAME=${DOWNLOADED_ARTIFACT_URL}

 # unzip app
 logMessage "Unzip ${APP_ARTIFACT_FILENAME}."
 unzip -q ${WORK_DIR}/${APP_ARTIFACT_FILENAME} -d ${UNZIP_DIR}
 
 # unzip conf (overwrite files WITHOUT prompting) (merge)
 logMessage "Unzip ${CONF_ARTIFACT_FILENAME}."
 unzip -o -q ${WORK_DIR}/${CONF_ARTIFACT_FILENAME} -d ${UNZIP_DIR}/conf
 chmod u+x ${UNZIP_DIR}/bin/*.sh
 
 # repertoire cible
 VERSION_DIR=${VERSIONS_DIR}/${APP_ARTIFACT_VERSION}
 
 if [ $APP_ARTIFACT_SNAPSHOT -eq 0 ]; then
  # cas d'un SNAPSHOT, on empile les SNAPSHOTS
  VERSION_DIR=${VERSIONS_DIR}/${APP_ARTIFACT_VERSION}-${TIMESTAMP}
 else
  # cas d'une RELEASE
  if [ -d ${VERSION_DIR} ]; then
   logError "The application \"${APP_ARTIFACT_VERSION}\" is already installed. Use \"-f\" (force) option to reinstall the same version."
   exit $EXIT_KO
  fi
 fi
 
 mkdir -p ${VERSIONS_DIR}
 cp -R ${UNZIP_DIR} ${VERSION_DIR}
 
 if [ ! -z ${APP_LISTEN_PORT} ]; then
  # append fichier run.cfg si on a transmis un arg server.port=xx avec l'action install
  updateRunCfgFile ${VERSION_DIR}/conf/run.cfg ${APP_LISTEN_PORT} ${APP_MANAGEMENT_PORT}
 fi
 
 rm ${VERSIONS_DIR}/todeploy 2> /dev/null
 ln -s ${VERSION_DIR} ${VERSIONS_DIR}/todeploy

 # on supprime les repertoires de versions obsoletes
 clean
 
 rm -R ${WORK_DIR}
 
 logMessage "The application ${APP_ARTIFACT_ID} [${APP_ARTIFACT_VERSION}] is installed in ${VERSION_DIR}."
}

# ----------------------------------------------------------------------------
# deploy
# ----------------------------------------------------------------------------
function deploy
{
 logMessage "- deploy"
 
 APP_ARTIFACT_VERSION=`readlink ${VERSIONS_DIR}/todeploy`
 
 if [ -z ${APP_ARTIFACT_VERSION} ]; then
  logError "No \"todeploy\" link in the versions dir. Perform \"install\" and retry."
  exit $EXIT_KO
 fi
 
 APP_ARTIFACT_VERSION=`echo $APP_ARTIFACT_VERSION | awk -F "/" '{print $NF}'`

 # est ce qu'on a deja une version en cours d'utilisation 
 currentVersionAndDisplay
 
 if [ ! -z ${CURRENT_VERSION} ]; then
  # on a une version en cours
  if [  "${VERSIONS_DIR}/${CURRENT_VERSION}" == "${VERSIONS_DIR}/${APP_ARTIFACT_VERSION}" ]; then
   logMessage "\"${APP_ARTIFACT_VERSION}\" is the current version <=> restart."
   invokeCurrentAppCmd "restart"
   failOnError $? "The \"restart\" step of deploy has failed."
   exit $EXIT_OK
  fi
  
  # on stop la version en cours
  stop
  failOnError $? "The \"stop\" step of deploy has failed."

  logMessage "Remove the current link."
  rm ${VERSIONS_DIR}/current
  rm ${VERSIONS_DIR}/previous 2> /dev/null
  
  logMessage "Create a previous link on \"${CURRENT_VERSION}\" (if rollback is needed)."
  ln -s ${VERSIONS_DIR}/${CURRENT_VERSION} ${VERSIONS_DIR}/previous
 fi
 
 # on cree le nouveau lien 
 logMessage "Create a new current link on \"${APP_ARTIFACT_VERSION}\"."
 ln -s ${VERSIONS_DIR}/${APP_ARTIFACT_VERSION} ${VERSIONS_DIR}/current
 rm ${VERSIONS_DIR}/todeploy
  
 # on demarre l'application
 start
 return $?
}

# ----------------------------------------------------------------------------
# clean
# ----------------------------------------------------------------------------
function clean
{
 logMessage "- clean"
 VERSION_DIRS_TO_KEEP="" 
 DELETE_COUNT=0
 
 cd ${VERSIONS_DIR}
 
 # on ne doit pas supprimer les liens et leur cible
 # on recupere les repertoires a conserver
 for VERSION_LINK in todeploy current previous; do
  VERSION_DIR_TO_KEEP=`readlink ${VERSION_LINK}`
  if [ ! -z ${VERSION_DIR_TO_KEEP} ]; then
   VERSION_DIR_TO_KEEP=`echo ${VERSION_DIR_TO_KEEP} | awk -F "/" '{print $NF}'`
   VERSION_DIRS_TO_KEEP="${VERSION_DIR_TO_KEEP} ${VERSION_DIRS_TO_KEEP}"
  fi
 done
 
 for VERSION_DIR_TO_CLEAN in $(ls -d * ); do
  # -h : True if FILE exists and is a symbolic link
  if [ ! -h ${VERSION_DIR_TO_CLEAN} ]; then
   # ce n'est pas un lien symbolique
   VERSION_DIR_FOUND=1
   # est ce que le repertoire fait parti de la liste des repertoire a supprimer
   for VERSION_DIR_TO_KEEP in $VERSION_DIRS_TO_KEEP; do
    if [ "${VERSION_DIR_TO_KEEP}" == "${VERSION_DIR_TO_CLEAN}" ]; then
     VERSION_DIR_FOUND=0
     break
    fi
   done
   if [ $VERSION_DIR_FOUND -eq 1 ]; then
    logMessage "Delete old version dir : \"${VERSION_DIR_TO_CLEAN}\"."
    rm -Rf ${VERSION_DIR_TO_CLEAN}
    DELETE_COUNT=$((DELETE_COUNT+1))
   fi
  fi 
 done 
 
 logMessage "$DELETE_COUNT delete(s)"

 cd - 1> /dev/null 
}

# ----------------------------------------------------------------------------
# rollback
# ----------------------------------------------------------------------------
function rollback
{
 logMessage "- rollback"
 
 # est ce qu'on a une version precedente a restaurer 
 PREVIOUS_VERSION=`readlink ${VERSIONS_DIR}/previous`
 
 if [ -z ${PREVIOUS_VERSION} ]; then
  logMessage "No previous version, impossible to rollback."
  exit $EXIT_OK
 fi
 
 # stop the current
 stop
 
 logMessage "Remove the current version."
 CURRENT_VERSION=`readlink ${VERSIONS_DIR}/current`
 # on supprime la version qui pose probleme
 rm ${VERSIONS_DIR}/current
 rm -Rf ${CURRENT_VERSION}
 rm ${VERSIONS_DIR}/previous
  
 logMessage "Restore the current link on ${PREVIOUS_VERSION}."
 ln -s ${PREVIOUS_VERSION} ${VERSIONS_DIR}/current
  
 currentVersion
 # on demarre l'application
 start
 return $?
}

# ----------------------------------------------------------------------------
# main
# ----------------------------------------------------------------------------

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

while [ $# != 0 ]
 do case $1 in
  -h | --help | help) 
   usage
   exit 0
   ;;
  install)
   CMD_INSTALL=0
   shift
   ;;
  deploy)
   CMD_DEPLOY=0
   shift
   ;;
  start)
   CMD_START=0
   shift
   ;;
  stop)
   CMD_STOP=0
   shift
   ;;
  status)
   CMD_STATUS=0
   shift
   ;;
  restart)
   CMD_RESTART=0
   shift
   ;;
  config)
   CMD_CONFIG=0
   shift
   ;;
  rollback)
   CMD_ROLLBACK=0
   shift
   ;;
  health)
   CMD_HCHECK=0
   shift
   ;;
  version)
   CMD_VERSION=0
   shift
   ;;
  clean)
   CMD_CLEAN=0
   shift
   ;;   
  management)
   CMD_MANAGEMENT=0
   shift
   ;;
  -p) 
   OPTION_PRINT=0
   shift
   ;;
  -u) 
   shift
   if [ -z $1 ]; then
    logError "The relative management uri is missing."
    exit $EXIT_KO 
   fi  
   MANAGEMENT_URI="-u $1"
   shift
   ;;       
  -nu)
   shift
   NEXUS_SEARCH_URL=$1
   shift
   ;;  
  -rn)
   shift
   RELEASE_REPOSITORY_NAME=$1
   shift
   ;;
  -sn)
   shift
   SNAPSHOT_REPOSITORY_NAME=$1
   shift
   ;;
  -ag)
   shift  
   APP_ARTIFACT_GROUP=$1
   shift
   ;;     
  -ai)
   shift  
   APP_ARTIFACT_ID=$1
   shift
   ;;
  -av)
   shift  
   APP_ARTIFACT_VERSION=$1
   shift
   ;;
  -ac)
   shift  
   APP_ARTIFACT_CLASSIFIER=$1
   shift
   ;;
  -cg)
   shift  
   CONF_ARTIFACT_GROUP=$1
   shift
   ;;     
  -ci)
   shift  
   CONF_ARTIFACT_ID=$1
   shift
   ;;
  -cv)
   shift  
   CONF_ARTIFACT_VERSION=$1
   shift
   ;;
  -cc)
   shift
   if [! -z $1 ]; then   
   	CONF_ARTIFACT_CLASSIFIER=$1
   	shift
   fi
   ;;  
  *=*)
   if [ $CMD_INSTALL -eq 0 ]; then
    ARG_KEY_VALUE=$1
    ARG_KEY=`echo $ARG_KEY_VALUE | cut -d "=" -f 1`
    if [ "server.port" == $ARG_KEY ]; then
     APP_LISTEN_PORT=`echo $ARG_KEY_VALUE | cut -d "=" -f 2`
     # legacy
     APP_MANAGEMENT_PORT=$((APP_LISTEN_PORT + 100))
     logMessage "install: APP_LISTEN_PORT     : ${APP_LISTEN_PORT}"
    elif [ "management.port" == $ARG_KEY ]; then
     APP_MANAGEMENT_PORT=`echo $ARG_KEY_VALUE | cut -d "=" -f 2`
     logMessage "install: APP_MANAGEMENT_PORT : ${APP_MANAGEMENT_PORT}"
    fi
   fi
   shift
   ;;       
  * ) 
   logError "Unknown parameter : \"$1\""
   usage
   exit $EXIT_KO 
   ;;		
 esac
done

if [ $CMD_VERSION -eq 0 ]; then
 CURRENT_VERSION_DIR=`readlink ${VERSIONS_DIR}/current`
 if [ $? -eq 0 ]; then
  echo ${CURRENT_VERSION_DIR} | awk -F/ '{print $NF}'
 fi 
 exit $EXIT_OK
fi

if [ $CMD_CLEAN -eq 0 ]; then
 clean
 exit $EXIT_OK
fi

if [ $CMD_INSTALL -eq 0 ]; then
 install
 exit $EXIT_OK
fi

if [ $CMD_DEPLOY -eq 0 ]; then
 deploy 
 failOnError $? "The \"deploy\" action has failed."
fi

if [ $CMD_ROLLBACK -eq 0 ]; then
 rollback
 failOnError $? "The \"rollback\" action has failed."
fi

if [ $CMD_CONFIG -eq 0 ]; then
 config
 failOnError $? "The \"config\" action has failed."
fi
 
if [ $CMD_RESTART -eq 0 ]; then
 restart
 failOnError $? "The \"restart\" action has failed."
else
 if [ $CMD_STOP -eq 0 ]; then
  stop
  failOnError $? "The \"stop\" action has failed."
 fi
 if [ $CMD_START -eq 0 ]; then
  start
  failOnError $? "The \"start\" action has failed."
 fi
fi

if [ $CMD_STATUS -eq 0 ]; then
 status
 failOnError $? "The \"status\" action has failed."
fi 

if [ $CMD_HCHECK -eq 0 ]; then
 healthCheck
 failOnError $? "The \"health\" action has failed."
fi

if [ $CMD_MANAGEMENT -eq 0 ]; then
 if [ "X$MANAGEMENT_URI" == "X" ] ; then
  failOnError $EXIT_KO "The management request uri is missing, use -u."
 fi
 management
 failOnError $? "The management request has failed."
fi

exit $EXIT_OK