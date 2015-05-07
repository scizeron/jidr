[![Build Status](https://travis-ci.org/scizeron/mmc.svg?branch=master)](https://travis-ci.org/scizeron/jidr)

# jidr

**j**ava **i**nstall **d**eploy **r**un

# basics

Allows to easily install, deploy and run a spring-boot app, packaged in a zip file (distrib zip file).
The zip file entries are :

* bin/ : app.sh 
* conf/ :  configuration directory
* app/ : spring-boot application jar file

The application configuration is also packaged in a zip file (with a env classifier)

The "install" phase adds the configuration content in the application conf/ sub directory.

The admin script supports the application versionning : install and deploy the 1.2.0, install the next, rollback.
The old applications versions are purged when a new one is installed and when the installed application number is reached. 

# admin

It can perform :

* start, stop, status, restart
* install
* deploy
* rollback
* health

Some new specific commands can be added in order to be forwared to the application.

# app

It receives commands from admin wich are :

* start
* stop
* status
* restart
* health
 
It can also reveive specfic command (management, counter ...)

# content repositories

The application and the configuration files can be located on a nexus instance (search API) or on a Amazon S3 bucket.


## Package the application

Add the maven plugin in your pom.xml application in order to produce a 'distrib' zip file.

    <plugin>
     <groupId>com.stfciz.jidr</groupId>
     <artifactId>app-runner-maven-plugin</artifactId>
     <version>1.0.5</version>
     <executions>
      <execution>
       <id>distrib</id>
       <goals><goal>distrib</goal></goals>
      </execution>
     </executions>
    </plugin>

## Package the configuration

In a zip file, you add all what is expected by your application. 

## Artifact naming examples 

* **application**: my-app will give my-app-_version_-**distrib**.**zip**
* **conf dev** : my-app-**conf-dev** will give my-app-**conf-dev**-_version_.**zip**
* **conf prod** : my-app-**conf-prod** will give my-app-**conf-prod**-_version_.**zip**


# Bootstrap _admin_

The admin.sh must be installed on the application nodes


# _app_ Installation

Invoke the following command with the following parameters : 
    
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
 
# _deploy_
 
Invoke the following command with the following parameters : 
    
    admin.sh deploy

If the current version is running, it will be stopped and flagged as _previous_ if rollback is needed.
The **to_deploy** application becomes the **current** application.


# _run_

The usuals commands are performed on the application **current"" version.


# multiple versions

Suppose you have versions : 1.0, 1.1 and you want to deploy the 1.2.

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

After installing , the old version 1.0 has been removed

* 1.3 : to_deploy
* 1.2 : current
* 1.1 : previous.

# keywords

java, spring-boot, spring-boot-actuator, versionning, shell 
 




 

