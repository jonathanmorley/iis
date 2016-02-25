#
# Author:: Seth Chisamore (<schisamo@chef.io>)
# Cookbook Name:: iis
# Recipe:: mod_application_initialization
#
# Copyright 2011, Chef Software, Inc.
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

include_recipe 'iis'

::Chef::Recipe.send(:include, Opscode::IIS::Helper)
install_type = lambda do
  iis_version = Gem::Version.new(get_iis_version)
  return case
         when iis_version < Gem::Version.new('7.0')
           nil
         when iis_version.match(Gem::Version.new('7.5'))
           :msi
         else
           :feature
         end
end

log 'Application Initialization module is not supported on IIS 7.0 or lower, ignoring' do
  only_if lazy { install_type.call == 'nil' }
end

local_file = ::File.join(Chef::Config[:file_cache_path], 'appwarmup_x64.msi')

remote_file local_file do
  source 'http://go.microsoft.com/fwlink/?LinkID=247817'
  checksum 'effe3bd96d5b1abd86b38aa05d50c8c2ff78efe1318e05b0ec93c0e7667b2a4c'
  only_if lazy { install_type.call == 'msi' }
end

windows_package 'Application Initialization Module' do
  source local_file
  options '/norestart'
  returns 3010
  notifies :request_reboot, 'reboot[IIS-ApplicationInit]', :immediately
  only_if lazy { install_type.call == 'msi' }
end

reboot 'IIS-ApplicationInit' do
  action :nothing
  reason 'Need to reboot when the run completes successfully.'
end

windows_feature 'IIS-ApplicationInit' do
  action :install
  only_if lazy { install_type.call == 'feature' }
end
