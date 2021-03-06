#
# Cookbook Name:: glance
# Recipe:: replicator
#
# Copyright 2012-2013, Rackspace US, Inc.
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

if node["glance"]["replicator"]["enabled"] and node["glance"]["api"]["default_store"] == "file"
  api_nodes = get_nodes_by_recipe("glance::replicator").map { |n| n["hostname"] }.join(",")

  execute "enable glance login" do
    command "usermod -s /bin/sh glance"
  end
 
  dsh_group "glance" do
    user "glance"
    admin_user "glance"
  end

  remote_file "/var/lib/glance/glance-image-sync.py" do
    source "https://raw.github.com/rcbops/glance-image-sync/#{node['glance']['replicator']['checksum']}/glance-image-sync.py"
    owner "glance"
    group "glance"
    mode "0755"
  end

  template "/etc/glance/glance-image-sync.conf" do
    source "glance-image-sync.conf.erb"
    owner "glance"
    group "glance"
    mode "0600"
    variables(:api_nodes => api_nodes, :rsync_user => node['glance']['replicator']['rsync_user'])
  end

  cron "glance-image-sync-cronjob" do
    minute  "*/#{node['glance']['replicator']['interval']}"
    command "/var/lib/glance/glance-image-sync.py both"
    user    "glance"
  end

  # required as we move from running as root to glance, can be removed eventually
  image_sync_log = "/var/log/glance/glance-image-sync.log"

  file image_sync_log do
    user  "glance"
    group "glance"
    only_if do
        File.exists?(image_sync_log) && File.stat(image_sync_log).gid == 0
    end
  end

  # clean up previous replicator
  file "/var/lib/glance/glance-replicator.sh" do
    action :delete
  end

  cookbook_file "/var/lib/glance/glance-replicator.py" do
    action :delete
  end

  # glance-image-sync cronjob was installed under root, we've since moved to glance user
  %w{glance-replicator glance-image-sync}.each do |name|
    cron name do
      action :delete
    end
  end
end
