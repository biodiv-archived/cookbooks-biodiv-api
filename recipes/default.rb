#
# Cookbook Name:: biodiv
# Recipe:: default
#
# Copyright 2014, Strand Life Sciences
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "biodiv-api::packages"
include_recipe "elasticsearch"
include_recipe "redis"

# setup geoserver
#include_recipe "geoserver-tomcat"
#include_recipe "geoserver-tomcat::postgresql"

#setup fileops 
#include_recipe "fileops"

# setup biodiversity nameparser
#include_recipe "biodiversity-nameparser"

# setup biodiv database
#include_recipe "biodiv::database"

# install nginx
#include_recipe "nginx"

# setup postfix
#include_recipe "postfix"

# create includes folder
#directory "#{node['nginx']['dir']}/include.d/" do
#  owner node.nginx.user
#  group node.nginx.group
#  action :create
#end

#  setup nginx biodiv conf
#template "#{node['nginx']['dir']}/include.d/#{node.biodivApi.appname}" do
#  source "nginx-biodiv-api.erb"
#  owner node.nginx.user
#  group node.nginx.group
#  notifies :restart, resources(:service => "nginx"), :immediately
#end

# install grails
include_recipe "gradle"
gradleCmd = "JAVA_HOME=#{node.java.java_home} #{node.biodivApi.extracted}/gradlew"
#"JAVA_HOME=#{node.java.java_home} /usr/local/gradle/bin/gradle"
biodivApiRepo = "#{Chef::Config[:file_cache_path]}/biodiv-api"
additionalConfig = "#{node.biodivApi.additional_config}"

bash 'cleanup extracted biodivApi' do
   code <<-EOH
   rm -rf #{node.biodivApi.extracted}
   rm -f #{additionalConfig}
   EOH
   action :nothing
   notifies :run, 'bash[unpack biodivApi]'
end

# download git repository zip
remote_file node.biodivApi.download do
  source   node.biodivApi.link
  mode     0644
  notifies :run, 'bash[cleanup extracted biodivApi]',:immediately
end

bash 'unpack biodivApi' do
  code <<-EOH
  cd "#{node.biodivApi.directory}"
  unzip  #{node.biodivApi.download}
  expectedFolderName=`basename #{node.biodivApi.extracted} | sed 's/.zip$//'`
  folderName=`basename #{node.biodivApi.download} | sed 's/.zip$//'`

  if [ "$folderName" != "$expectedFolderName" ]; then
      mv "$folderName" "$expectedFolderName"
  fi

  EOH
  not_if "test -d #{node.biodivApi.extracted}"
  notifies :create, "template[#{additionalConfig}]",:immediately
  #notifies :run, "bash[copy static files]",:immediately
end

bash 'copy static files' do
  code <<-EOH
  mkdir -p #{node.biodiv.data}/images
  cp -r #{node.biodiv.extracted}/web-app/images/* #{node.biodiv.data}/images
  chown -R tomcat:tomcat #{node.biodiv.data}
  EOH
  only_if "test -d #{node.biodiv.extracted}"
end


# Setup user/group
poise_service_user "tomcat user" do
  user "tomcat"
  group "tomcat"
  shell "/bin/bash"
end

bash "compile_biodivApi" do
  code <<-EOH
  cd #{node.biodivApi.extracted}
  yes | export BIODIV_API_CONFIG_LOCATION=#{additionalConfig}
  yes | #{gradleCmd} war
  chmod +r #{node.biodivApi.war}
  EOH

  not_if "test -f #{node.biodivApi.war}"
  only_if "test -f #{additionalConfig}"
  notifies :run, "bash[copy additional config]", :immediately
end

bash "copy additional config" do
# code <<-EOH
#  mkdir -p /tmp/biodiv-temp/WEB-INF/lib
#  mkdir -p ~tomcat/.grails
#  cp #{additionalConfig} ~tomcat/.grails
#  cp #{additionalConfig} /tmp/biodiv-temp/WEB-INF/lib
#  cd /tmp/biodiv-temp/
#  jar -uvf #{node.biodiv.war}  WEB-INF/lib
#  chmod +r #{node.biodiv.war}
#  #rm -rf /tmp/biodiv-temp
#  EOH
  notifies :enable, "cerner_tomcat[#{node.biodiv.tomcat_instance}]", :immediately
  action :nothing
end

#  create additional-config
template additionalConfig do
  source "biodiv-api.properties.erb"
  notifies :run, "bash[compile_biodivApi]"
  notifies :run, "bash[copy additional config]"
end

cerner_tomcat node.biodiv.tomcat_instance do
  version "8.5.27"
  web_app "biodiv-api" do
    source "file://#{node.biodivApi.war}"

#    template "META-INF/context.xml" do
#      source "biodiv.context.erb"
#    end
  end

  java_settings("-Xms" => "512m",
                "-D#{node.biodiv.appname}_CONFIG_LOCATION=".upcase => "#{node.biodiv.additional_config}",
                "-D#{node.biodivApi.configname}".upcase => "#{node.biodivApi.additional_config}",
                "-D#{node.fileops.appname}_CONFIG=".upcase => "#{node.fileops.additional_config}",
                "-Dlog4jdbc.spylogdelegator.name=" => "net.sf.log4jdbc.log.slf4j.Slf4jSpyLogDelegator",
                "-Dfile.encoding=" => "UTF-8",
                "-Dorg.apache.tomcat.util.buf.UDecoder.ALLOW_ENCODED_SLASH=" => "true",
                "-Xmx" => "4g",
                "-XX:PermSize=" => "512m",
                "-XX:MaxPermSize=" => "512m",
                "-XX:+UseParNewGC" => "")

  action	:nothing
  only_if "test -f #{node.biodivApi.war}"
end
