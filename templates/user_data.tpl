#!/bin/bash

# Do not set the set -x flag
# This will cause passwords to be printed to the console and log files.

HOSTNAME="$(hostname)"
ARTIFACTORY='${artifactory-url}'
EC2_USER='ec2-user'

# USER-DATA SHIPPED TO LOGS
exec > >(tee /var/log/user-data.log|logger -t user-data ) 2>&1
echo "Running user_data script ($0)"
echo "  as $(whoami) in $PROJ_ENV environment"
date '+%Y-%m-%d %H:%M:%S'

umask 022

# INSTALLING CURL
sudo apt-get install curl -y

# INSTALLING DOCKER
curl -fsSL https://get.docker.com/ | sh

# CREATING 

# CONFIGURE FIREWALL USING UFW
sudo apt-get install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 28015
sudo ufw allow 28015/udp
sudo ufw allow 28016
sudo ufw allow 8080
sudo ufw enable

# START THE RUST CONTAINER.  DOWNLOADS LATEST RUST-SERVER IMAGE FROM DOCKER HUB
docker run --name rust-server didstopia/rust-server

#



# ADD THE BAAT ARTIFACTORY REPO

cat >/etc/yum.repos.d/artifactory-baat-el7-x86_64-repo.repo <<EOL
[artifactory-baat-el7-x86_64-repo]
name=RedHat Based Linux 7 Server - BAAT
baseurl=https://artifactory.nike.com/artifactory/baat-rpm-local/el7/x86_64
enabled=1
gpgcheck=0
priority=3
EOL

#--
# UPDATE YUM
# yum is using Nike RPM Repos if using CIS approved AMIs.
#   Also, fetch *nix tools we'll need and want.
#--
echo "Update Yum"
yum -y update --skip-broken
yum -y install wget zip unzip postgresql94 git tree vim telnet nc tcpdump


# ADD A.BAAT ACCOUNT
echo "Create $USER_NAME user and group account"
groupadd $USER_NAME && useradd -g $USER_NAME $USER_NAME


# INSTALL A.BAAT SSH KEYS

echo "Install $USER_NAME SSH KEY"

SSH_DIR="/home/$USER_NAME/.ssh"

mkdir -p  $SSH_DIR
chmod 700 $SSH_DIR

cat >$SSH_DIR/id_rsa  <<EOL
$USER_SSH_PRIVATE_KEY
EOL

chmod 600 $SSH_DIR/id_rsa

cat >$SSH_DIR/id_rsa.pub  <<EOL
$USER_SSH_PUBLIC_KEY
EOL

# Trust A.BAAT ssh keys
cat >$SSH_DIR/authorized_keys  <<EOL
$USER_SSH_PUBLIC_KEY
EOL

# Set up ssh options to make git work correctly
cat >$SSH_DIR/config  <<EOL
Host *
  IdentityFile ~/.ssh/id_rsa
  StrictHostKeyChecking no
  ForwardX11 no
  PasswordAuthentication no
  CheckHostIP no
EOL

chown -R $USER_NAME:$USER_NAME  $SSH_DIR
chmod 600 $SSH_DIR/authorized_keys $SSH_DIR/config


# PULL DOWN UTIL DIRECTORY
mkdir -p  /opt/util /opt/temp
chown $USER_NAME  /opt/util
chgrp $USER_NAME  /opt  /opt/util /opt/temp
chmod g+rw        /opt  /opt/util /opt/temp
curl -s https://artifactory.nike.com/artifactory/baat-generic-local/aws/util/opt.util.tgz  | su a.baat -c 'tar xzpvf - -C /opt/util'

echo "Capture local vars in /opt/deploy.vars"

cat >/opt/deploy.vars  <<EOL
APP_NAME="$APP_NAME"
PROJ_ENV="$PROJ_ENV"
DEPLOYDATE="$(date '+%Y-%m-%d %H:%M:%S %Z')"
EOL


# SERVICE TO SEND A BOOT NOTIFICATION TO SLACK
echo "Setting up deploynotice to alert in slack"

cat >/etc/systemd/system/deploynotice.service <<EOL
[Unit]
Description=Sends a notification to Slack #baat-aws-dev channel.
After=network.target

[Service]
Type=simple
ExecStart=/opt/util/bin/send-deploy-notice.sh
TimeoutStartSec=10

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable deploynotice.service
systemctl start deploynotice


# INSTALL NEW RELIC INFRASTRUCTURE AGENT
echo "Install New Relic Infrastructure Agent"

cat >/etc/newrelic-infra.yml <<EOL
license_key: $NEWRELIC_LICENSE_KEY
display_name: AWS:$APP_NAME-$PROJ_ENV
EOL

curl -o /etc/yum.repos.d/newrelic-infra.repo  \
    https://download.newrelic.com/infrastructure_agent/linux/yum/el/7/x86_64/newrelic-infra.repo
yum -q makecache -y --disablerepo='*' --enablerepo='newrelic-infra'
yum install -y newrelic-infra


# INSTALL ORACLE JAVA JDK 8
echo "Install Java 8 JDK"
wget --directory-prefix=/tmp "$ARTIFACTORY/$JDK_DOWNLOAD_PATH/$JDK_RPM_NAME"
yum -y localinstall /tmp/$JDK_RPM_NAME
rm -f /tmp/$JDK_RPM_NAME

# Pull in Nike root certs
cp /usr/java/latest/jre/lib/security/cacerts  \
    /usr/java/latest/jre/lib/security/cacerts.orig

wget -q "$ARTIFACTORY/$JDK_DOWNLOAD_PATH/cacerts"  \
    -O /usr/java/latest/jre/lib/security/cacerts


# INSTALL NEW RELIC JVM AGENT
echo "Install New Relic JVM APM Agent"

cd /tmp

wget -q "$ARTIFACTORY/newrelic/$NEWRELIC_FILE_NAME"

# Move install directory into place, preserving any previous version
if [[ -d /opt/newrelic ]]; then
    TS=`date +'%Y%m%d'`
    mv /opt/newrelic /opt/newrelic.$TS
fi

# This creates /opt/newrelic for APM agent
unzip $NEWRELIC_FILE_NAME -d /opt

# Clean up temp files
rm -f $NEWRELIC_FILE_NAME

# Change ownership to a.baat user
chown -R $USER_NAME:$USER_NAME /opt/newrelic


# INSTALL NEWRELIC.YML File
echo "Install newrelic.yml file"
cat >/opt/newrelic/newrelic.yml <<EOL
# This file is managed by Terraform !!
#######################################
####   DO NOT MODIFY MANUALLY      ####
#######################################
common: &default_settings
  license_key: $NEWRELIC_LICENSE_KEY
  agent_enabled: true
  app_name: AWS:$APP_NAME:$PROJ_ENV
production:
  <<: *default_settings
EOL


# INSTALL ATLASSIAN APP
echo "Install $APP_NAME"
INSTALLER=$APP_INSTALLER_FILE_NAME		   # Name of installer
PULL_INST="$ARTIFACTORY/$APP_NAME/$INSTALLER"
# ^ instead of https://www.atlassian.com/software/crowd/downloads/binary/$INSTALLER
INSTBASE=$APP_DIRECTORY_NAME               # Name of unzipped install dir

#--
# Fetch latest Postgres driver from Artifactory
# ^ instead of https://jdbc.postgresql.org/download/$JDBCLIB
#--
JDBCLIB=$JDBC_FILE_NAME
JDBCURL="$ARTIFACTORY/$APP_NAME/jdbc/$JDBCLIB"

# Create temp working directory, do work there
mkdir -p /opt/$APP_NAME
chmod 775 /opt/temp
cd /opt/temp

# Pull and unpack installer
wget -q $PULL_INST
unzip $INSTALLER

# Move install directory into place
if [[ -d /opt/$APP_NAME/$INSTBASE ]]; then
    TS=$(date +'%Y%m%d')
    mv /opt/$APP_NAME/$INSTBASE /opt/$APP_NAME/$INSTBASE.$TS
fi

mv $INSTBASE  /opt/$APP_NAME/$INSTBASE
rm $INSTALLER

if [[ ! -d /opt/$APP_NAME/$INSTBASE/crowd-webapp ]]; then
    echo "ABORT $0 -- /opt/$APP_NAME/$INSTBASE/crowd-webapp not found."
    exit 1
fi

# Update app symbolic link
echo "Updating sym link"
rm -f /opt/$APP_NAME/latest
ln -s $INSTBASE /opt/$APP_NAME/latest

# Update JDBC Library in Tomcat lib dir
echo "Install JDBC JAR"
wget -q -P /tmp $JDBCURL
mv /tmp/$JDBCLIB /opt/$APP_NAME/latest/apache-tomcat/lib

# Create crowd data home and shared directory then point crowd-init.properties file to the home dir
echo "Install crowd-init.properties and setenv.sh"
mkdir -p /opt/data/$APP_NAME /opt/data/$APP_NAME-shared
wget -q "$ARTIFACTORY/$APP_NAME/config/crowd-init.properties" \
    -O /opt/$APP_NAME/latest/crowd-webapp/WEB-INF/classes/crowd-init.properties

wget -q "$ARTIFACTORY/$APP_NAME/config/setenv.sh" \
    -O /opt/$APP_NAME/latest/apache-tomcat/bin/setenv.sh

# INSTALL server.xml
echo "Install server.xml"
cat >/opt/crowd/latest/apache-tomcat/conf/server.xml <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8020" shutdown="SHUTDOWN">

    <Service name="Catalina">

        <Connector acceptCount="100"
                   connectionTimeout="20000"
                   disableUploadTimeout="true"
                   enableLookups="false"
                   maxHttpHeaderSize="8192"
                   maxThreads="150"
                   minSpareThreads="25"
                   port="8095"
                   scheme="https"
                   secure="true"
                   useBodyEncodingForURI="true"
                   URIEncoding="UTF-8"
                   compression="on"
                   proxyName="$APP_DOMAIN_NAME"
                   proxyPort="443"
                   compressableMimeType="text/html,text/xml,application/xml,text/plain,text/css,application/json,application/javascript,application/x-javascript" />

        <Engine defaultHost="localhost" name="Catalina">
            <Host appBase="webapps" autoDeploy="true" name="localhost" unpackWARs="true"/>
        </Engine>

        <!-- To connect to an external web server (typically Apache) -->
        <!-- Define an AJP 1.3 Connector on port 8009 -->
        <!--
            <Connector port="8009" enableLookups="false" redirectPort="8443" protocol="AJP/1.3" />
        -->
    </Service>

    <!-- Security listener. Documentation at /docs/config/listeners.html
    <Listener className="org.apache.catalina.security.SecurityListener" />
    -->
    <!--APR library loader. Documentation at /docs/apr.html -->
    <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
    <!--Initialize Jasper prior to webapps are loaded. Documentation at /docs/jasper-howto.html -->
    <Listener className="org.apache.catalina.core.JasperListener" />
    <!-- Prevent memory leaks due to use of particular java/javax APIs-->
    <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
    <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
    <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

</Server>
EOL

# INSTALL crowd.cfg.xml
echo "Install crowd.cfg.xml"
cat >/opt/data/crowd/crowd.cfg.xml <<EOL
<?xml version="1.0" encoding="UTF-8"?>

<application-configuration>
  <setupStep>complete</setupStep>
  <setupType>install.xml</setupType>
  <buildNumber>727</buildNumber>
  <properties>
    <property name="crowd.server.id">$APP_SERVER_ID</property>
    <property name="hibernate.c3p0.acquire_increment">1</property>
    <property name="hibernate.c3p0.idle_test_period">100</property>
    <property name="hibernate.c3p0.max_size">30</property>
    <property name="hibernate.c3p0.max_statements">0</property>
    <property name="hibernate.c3p0.min_size">0</property>
    <property name="hibernate.c3p0.timeout">30</property>
    <property name="hibernate.connection.driver_class">org.postgresql.Driver</property>
    <property name="hibernate.connection.password">$APP_DB_PASSWORD</property>
    <property name="hibernate.connection.url">jdbc:postgresql://$DB_URL:5432/$DB_NAME</property>
    <property name="hibernate.connection.username">$APP_DB_USER</property>
    <property name="hibernate.dialect">org.hibernate.dialect.PostgreSQLDialect</property>
    <property name="hibernate.setup">true</property>
    <property name="license">$APP_LICENSE_KEY</property>
  </properties>
</application-configuration>
EOL

# INSTALL crowd.properties
echo "Install crowd.properties"
cat >/opt/data/crowd/crowd.properties <<EOL
session.lastvalidation=session.lastvalidation
session.tokenkey=session.tokenkey
crowd.server.url=https\://$APP_DOMAIN_NAME/$APP_NAME/services/
application.name=$APP_NAME
http.timeout=30000
session.isauthenticated=session.isauthenticated
application.login.url=https\://$APP_DOMAIN_NAME/$APP_NAME
session.validationinterval=0
application.password=$APP_PASSWORD
EOL

# Change user:group ownership of the installation directories.

chown -R $USER_NAME:$USER_NAME /opt/$APP_NAME
chown -R $USER_NAME:$USER_NAME /opt/data/$APP_NAME

# Put crowd start and stop under systemd control
echo "Install crowd systemd"
cat >/etc/systemd/system/$APP_NAME.service <<EOL
[Unit]
Description=Starts and stops the $APP_NAME Server
DefaultDependencies=no

[Service]
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=/opt/$APP_NAME/latest
Type=simple
RemainAfterExit=true
ExecStart=/opt/$APP_NAME/latest/start_$APP_NAME.sh
ExecStop=/opt/$APP_NAME/latest/stop_$APP_NAME.sh
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable $APP_NAME.service
systemctl start $APP_NAME
systemctl status $APP_NAME



# INSTALL/CONFIGURE CLOUDWATCH LOGS AGENT
echo "Install Cloudwatch log agent"
cat >/tmp/$APP_NAME.conf <<EOL
[general]
state_file= /var/awslogs/state/agent-state
[$APP_NAME]
file = /opt/data/$APP_NAME/logs/atlassian-$APP_NAME.log
log_stream_name = $HOSTNAME
log_group_name = $CLOUDWATCH_PREFIX/opt/data/$APP_NAME/logs/atlassian-$APP_NAME.log
datetime_format = %d %b %Y %H:%M:%S
[$APP_NAME-SERVER]
file = /var/log/messages
log_stream_name = $HOSTNAME
log_group_name = $CLOUDWATCH_PREFIX/var/log/messages
datetime_format = %d %b %Y %H:%M:%S
EOL

wget -q -P /tmp https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py
python /tmp/awslogs-agent-setup.py -n -r $AWS_REGION -c /tmp/$APP_NAME.conf

echo "END user_data script execution"
date '+%Y-%m-%d %H:%M:%S %Z'
