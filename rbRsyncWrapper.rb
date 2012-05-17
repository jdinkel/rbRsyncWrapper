#!/usr/bin/env ruby

raise 'Must run as root' unless Process.uid == 0

script_directory = File.dirname(__FILE__)

require "bundler/setup"
require File.join script_directory, 'libs', 'rbrsyncwrapper.rb'
require 'open3'
require 'yaml'

EMAIL_TEMPLATE_LOCATION = File.join script_directory, "templates", "email_notification.markdown.erb"

#backup_log = File.join script_directory, "logs", 'backup_log.txt'
password_file = File.join script_directory, 'config', 'rsync_password.file'
config_file = File.join script_directory, 'config', 'config.yml'

begin
  config = YAML.load File.read(config_file)
  raise if config['send_to'].nil? || config['email_server'].nil?
rescue
  puts "Error reading the configuration file."
  exit(false)
end

# Just making sure the password file is secure
`chown root.adm #{password_file}`
`chmod 660 #{password_file}`

backup_start = Time.now

# do the rsync

rsync_command = "/usr/bin/rsync -hrtz --inplace --no-p --no-g \
--chmod=ugo=rwX --delete --stats --password-file=#{password_file} \
rsyncuser1@server2.company.com::Share-Backup_Snap \
/mnt/btr_pool/files_share_backup/ \
--sockopts=SO_SNDBUF=4194304,SO_RCVBUF=4194304"

stdin, rsync_result, stderr = Open3.popen3(rsync_command)
rsync_result = rsync_result.read.split.join("  \n")

puts rsync_result

# do the snapshot

snapshot_command = "/sbin/btrfs subvolume snapshot \
/mnt/btr_pool/files_share_backup /mnt/btr_pool/\
files_share_backup-snap-#{backup_start.strftime("%Y.%m.%d-%H.%M.%S")}"

stdin, snapshot_result, stderr = Open3.popen3(snapshot_command)
snapshot_result = snapshot_result.read

puts snapshot_result

# Send the email

email_params = { :name =>              config['send_to_name'],
                 :address =>           config['send_to'],
                 :email_server =>      config['email_server'],
                 :sender_address =>    config['send_from'],
                 :sender_name =>       config['send_from_name'],
                 :rsync_result =>      rsync_result,
                 :snapshot_result =>   snapshot_result,
                 :backup_start_time => backup_start
               }

email = create_email(email_params)
email.deliver!
