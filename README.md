[![Build Status](https://travis-ci.org/scizeron/mmc.svg?branch=master)](https://travis-ci.org/scizeron/jidr)

# jidr

**j**ava **i**nstall **d**eploy **r**un

# basics

Allows to easily install, deploy and run a spring-boot app, packaged in a zip file (distrib zip file).
The zip file entries are :

* bin/ : app.sh 
* conf/ :  configuration directory
* app/ : spring-boot application jar file

The application configuration is also packaged in a zip file.

The "install" phase merges the configuration content in the application conf/ sub directory.

The admin script supports the application versionning : install and deploy the 1.2.0, install the next one, rollback if needed ... etc.

# admin.sh _script_

It can perform :

* start, stop, status, restart
* install
* deploy
* rollback
* health

Some new specific commands can be added as could be forwarded to the application.

# app.sh _script_

It receives commands from the admin script :

* start
* stop
* status
* restart
* health
 
It can also reveive specfic command (management, counter ...)

# Repositories

The application and the configuration files can be located on a nexus instance (search API) or in a Amazon S3 bucket.

# Package the application

Add the maven plugin in your pom.xml application in order to produce a 'distrib' zip file.

    <plugin>
     <groupId>com.github.scizeron.jidr</groupId>
     <artifactId>jidr-app-maven-plugin</artifactId>
     <version>1.0.9-SNAPSHOT</version>
     <executions><execution><goals><goal>package</goal></goals></execution></executions>
    </plugin>

# Package the configuration

In a zip file, you add all is expected by your application. 

# Artifact naming examples 

* **application**: my-app will give my-app-_version_-**distrib**.**zip**
* **conf dev** : my-app-**conf-dev** will give my-app-**conf-dev**-_version_.**zip**
* **conf prod** : my-app-**conf-prod** will give my-app-**conf-prod**-_version_.**zip**

# Bootstrap _admin_

The admin.sh must be installed on the target application nodes (once per application and a application supports several versions).

# _app_ installation

Invoke the following command with the following options : 
    
    admin.sh install

* **-ag** : Application Groupid
* **-ai** : Application artifactId 
* **-av** : Application Version
* **-ac** : Application classifier (distrib)
* **-ap** : Application packaging (zip)
* **-cg** : Configuration Groupid
* **-ci** : Configuration artifactId 
* **-cv** : Configuration Version
* **-cc** : Configuration classifier (optional)
* **-cp** : Configuration packaging (zip)
* **-nu** : Nexus search Url (if you use nexus)
* **-rn** : Release repository Name (if you use nexus)
* **-sn** : Snapshot repository Name (if you use nexus)
* **-s3b** : AWS S3 repository apps bucket (if you use aws s3)

When the new application is installed, its location is under **versions/**. 
A symbolic link **to_deploy** refereces the application directory. It will be present for the next step **deploy**
 
# _app_ deployment
 
Invoke the following command : 
    
    admin.sh deploy

If the current version is running, it will be stopped and flagged as _previous_ if rollback is needed.
The **to_deploy** application becomes the **current** application.

# _app_ rollback
 
Invoke the following command  if the previous deployment has been failed : 
    
    admin.sh rollback

# _app_ run

The usual commands are performed on the **current** version application.

# _app_ versions

Suppose you have 2 versions : 1.0, 1.1 and you want to deploy the new 1.2.

Before installing : 

* 1.1 : current
* 1.0 : previous.

After installing : 

* 1.2 : to_deploy
* 1.1 : current
* 1.0 : previous.

After deploying : 

* 1.2 : current
* 1.1 : previous
* 1.0 : 

And now, suppose you want to deploy the 1.3.
After installing, the old version 1.0 has been removed.

* 1.3 : to_deploy
* 1.2 : current
* 1.1 : previous.

# keywords

java, spring-boot, spring-boot-actuator, versionning, shell 


