/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package com.github.scizeron.jidr.maven.plugin;


import java.io.File;
import java.io.FileFilter;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

import net.lingala.zip4j.core.ZipFile;
import net.lingala.zip4j.model.ZipParameters;

import org.apache.commons.io.Charsets;
import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.io.LineIterator;
import org.apache.maven.plugin.AbstractMojo;
import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.Component;
import org.apache.maven.plugins.annotations.LifecyclePhase;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;
import org.apache.maven.plugins.annotations.ResolutionScope;
import org.apache.maven.project.MavenProject;
import org.apache.maven.project.MavenProjectHelper;

/**
 * Zip package a jar application with sub dirs : app, bin, conf
 * 
 */
@Mojo( name = "package", requiresDependencyResolution = ResolutionScope.COMPILE, defaultPhase = LifecyclePhase.VERIFY)
public class JidrPackageApp extends AbstractMojo {

  /**
   * 
   */
  private final static String DISTRIB_TYPE = "zip";

  /**
   * 
   */
  private final static String APP_SH_FILE  = "app.sh";
  
  /**
   * 
   */
  private final static String APP_CFG_FILE = "artifact.cfg";

  /**
   * 
   */
  @Parameter(defaultValue="${project}", required=true, readonly = true)
  private MavenProject        project;

  @Component
  private MavenProjectHelper  mavenProjectHelper;

  /**
   * 
   */
  @Parameter(defaultValue="distrib")
  private String              classifier;

  @Override
  public void execute() throws MojoExecutionException {
    InputStream input = null;
    FileOutputStream output = null;

    if ("pom".equals(this.project.getPackaging())) {
      getLog().info("Skip execute on " + this.project.getPackaging() + " project.");
      return;
    }
    
    final String outputDirname = this.project.getBuild().getDirectory() + File.separator + "distrib";

    final String libOutputDir = outputDirname + File.separator + "lib";
    final String appOutputDir = outputDirname + File.separator + "app";
    final String confOutputDir = outputDirname + File.separator + "conf";
    final String binOutputDir = outputDirname + File.separator + "bin";

    try {
      new File(libOutputDir).mkdirs();
      new File(appOutputDir).mkdirs();
      new File(binOutputDir).mkdirs();
      new File(confOutputDir).mkdirs();

      File outputFile = new File(binOutputDir + File.separator + APP_SH_FILE);
      output = new FileOutputStream(outputFile);

      input = JidrPackageApp.class.getClassLoader().getResourceAsStream(APP_SH_FILE);
      final LineIterator lineIterator = IOUtils.lineIterator(input, Charsets.UTF_8);
      while (lineIterator.hasNext()) {
        output.write((lineIterator.nextLine() + "\n").getBytes());
      }
      output.close();

      getLog().info(String.format("Create \"%s\" in %s.", APP_SH_FILE, binOutputDir));
      
      outputFile = new File(confOutputDir + File.separator + APP_CFG_FILE);
      output = new FileOutputStream(outputFile);

      output.write(new String("APP_ARTIFACT=" + project.getArtifactId() + "\n").getBytes());
      output.write(new String("APP_PACKAGING=" + project.getPackaging() + "\n").getBytes());
      output.write(new String("APP_VERSION=" + project.getVersion()).getBytes());

      getLog().info(String.format("Create \"%s\" in %s.", APP_CFG_FILE, confOutputDir));

      // si un repertoire src/main/bin est present dans le projet, le contenu
      // sera copie dans binOutputDir
      addExtraFiles(this.project.getBasedir().getAbsolutePath() + "/src/main/bin", binOutputDir);

      // si un repertoire src/main/conf est present dans le projet, le contenu
      // sera copie dans confOutputDir
      addExtraFiles(this.project.getBasedir().getAbsolutePath() + "/src/main/conf", confOutputDir);

      final String artifactFilename = this.project.getBuild().getFinalName() + "." + this.project.getPackaging();
      
      FileUtils.copyFileToDirectory(new File(this.project.getBuild().getDirectory() + File.separator + artifactFilename), new File(appOutputDir));

      getLog().info(String.format("Copy \"%s\" to %s.", artifactFilename, appOutputDir));

      String distribFilename = this.project.getArtifactId() + "-" + this.project.getVersion() + "-" + classifier + "." + DISTRIB_TYPE;

      ZipFile distrib = new ZipFile(this.project.getBuild().getDirectory() + File.separator + distribFilename);
      ZipParameters zipParameters = new ZipParameters();
      distrib.addFolder(new File(binOutputDir), zipParameters);
      distrib.addFolder(new File(appOutputDir), zipParameters);
      distrib.addFolder(new File(confOutputDir), zipParameters);

      getLog().info(String.format("Create \"%s\" to %s.", distribFilename, this.project.getBuild().getDirectory()));

      this.mavenProjectHelper.attachArtifact(this.project, DISTRIB_TYPE, classifier, distrib.getFile());
      getLog().info(String.format("Attach \"%s\".", distribFilename));

    } catch (Exception exception) {
      getLog().error(exception);

    } finally {
      try {
        if (output != null) {
          output.close();
        }
        if (input != null) {
          input.close();
        }
      } catch (IOException e) {
        getLog().error(e);
      }
    }
  }

  /**
   * 
   * @param inputDirectoryName
   * @param outputDirName
   * @throws Exception
   */
  private void addExtraFiles(String inputDirectoryName, String outputDirName) throws Exception {
    final File inputDirectory = new File(inputDirectoryName);
    final File outputDirectory = new File(outputDirName);

    if (!inputDirectory.exists()) {
      return;
    }

    getLog().info(String.format("Add the \"%s\" file(s) in %s.", inputDirectoryName, outputDirName));

    FileUtils.copyDirectory(inputDirectory, outputDirectory, new FileFilter() {
      @Override
      public boolean accept(File file) {
        return true;
      }
    }, true);

    getLog().info(String.format("The \"%s\" contains :", outputDirName));
    final String[] files = outputDirectory.list();
    for (String file : files) {
      getLog().info(String.format(" - %s", file));
    }
  }
}