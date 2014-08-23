#
# Cookbook Name:: opennms
# Recipe:: default
#
# Copyright 2014, The OpenNMS Group, Inc.
#
# All rights reserved - Do Not Redistribute
#
include_recipe "yum"
include_recipe "postgresql::server"

case node['platform_family']
when "rhel"
  # Install yum repository on Red Hat family linux
  # Set OpenNMS home dir for RHEL systems
  home_dir = "/opt/opennms"

  # add the OpenNMS common yum repository
  yum_repository "opennms-common" do
    description "RPMs Common to All OpenNMS Architectures (#{node['opennms']['release']})"
    baseurl "http://yum.opennms.eu/#{node['opennms']['release']}/common"
    gpgkey "http://yum.opennms.eu/OPENNMS-GPG-KEY"
    action :create
  end

  # add the OpenNMS yum repository
  yum_repository "opennms-rhel6" do
    description "RedHat Enterprise Linux 6.x and CentOS 6.x (#{node['opennms']['release']})"
    baseurl "http://yum.opennms.eu/#{node['opennms']['release']}/rhel6"
    gpgkey "http://yum.opennms.eu/OPENNMS-GPG-KEY"
    action :create
  end

  # add the EPEL repo
  yum_repository 'epel' do
    description 'Extra Packages for Enterprise Linux'
    mirrorlist 'http://mirrors.fedoraproject.org/mirrorlist?repo=epel-6&arch=$basearch'
    gpgkey 'http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6'
    action :create
  end

  # Run update
  execute "Update yum repository" do
    command "yum -y update"
  end

when "debian"
# Install aptitude repository on Debian family
  home_dir = "/usr/share/opennms"
  template "/etc/apt/sources.list.d/opennms.list" do
    source "opennms.list.erb"
    owner "root"
    group "root"
    mode "0644"
  end

  remote_file "#{Chef::Config['file_cache_path']}/OPENNMS-GPG-KEY" do
    source "http://debian.opennms.org/OPENNMS-GPG-KEY"
  end

  execute "Install OpenNMS apt GPG-key" do
    command "sudo apt-key add #{Chef::Config['file_cache_path']}/OPENNMS-GPG-KEY"
    action :run
  end

  execute "Update apt repository" do
    command "aptitude update"
    action :run
  end
end

# Install OpenNMS and Java RRDtool library
["opennms", "jrrd"].each do |package_name|
  package "#{package_name}" do
    action :install
  end
end

# Install and overwrite Java with configurable version
include_recipe "java"

# Set Java environment for OpenNMS
execute "Setup opennms java" do
  command "#{home_dir}/bin/runjava -s"
  action :run
end

# Install OpenNMS configuration templates
{ "opennms.conf" => "opennms.conf.erb",
  "opennms.properties" => "opennms.properties.erb",
  "rrd-configuration.properties" => "rrd-configuration.properties.erb",
  "opennms-datasources.xml" => "opennms-datasources.xml.erb",
  "provisiond-configuration.xml" => "provisiond-configuration.xml.erb",
  "discovery-configuration.xml" => "discovery-configuration.xml.erb",
}.each do |dest, source|
  template "#{home_dir}/etc/#{dest}" do
    source "#{source}"
    owner "root"
    group "root"
    mode "0640"
  end
end

# Install OpenNMS database schema
execute "Initialize OpenNMS database and libraries" do
  command "#{home_dir}/bin/install -dis"
  action :run
end

# Enable predefined set of OpenNMS services
cookbook_file "service-configuration.xml" do
  path "#{home_dir}/etc/service-configuration.xml"
  action :create
end

# Install opennms as service and set runlevel
service "opennms" do
  action [:enable, :start]
end