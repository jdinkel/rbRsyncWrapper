require 'mail'
require 'erubis'
require 'redcarpet/compat'

def all_snaps
  Dir.glob '/mnt/btr_pool/files02_share_backup-snap-*'
end

def oldest_snap_time
  x = all_snaps[-1].split('-')[-2..-1].join('.').split('.')
  Time.new(x[0], x[1], x[2], x[3], x[4], x[5])
end

def determine_time(start_time)

  length = Time.now - start_time
  hours = (length / 3600).to_i
  remaining = length - (hours * 3600)
  minutes = (remaining / 60).to_i
  seconds = (remaining - (minutes * 60)).to_i

  # build the string result
  string_result = ''
  unless hours == 0
    string_result = "#{hours} hour"
    string_result = "#{string_result}s" unless hours == 1
    if seconds == 0 && minutes != 0 or seconds != 0 && minutes == 0
      string_result = "#{string_result} and"
    end
    string_result = "#{string_result} " unless minutes == 0 && seconds == 0
  end
  unless minutes == 0
    string_result = "#{string_result}#{minutes} minute"
    string_result = "#{string_result}s" unless minutes == 1
    unless seconds == 0
      string_result = "#{string_result} and"
    end
    string_result = "#{string_result} " unless seconds == 0
  end
  unless seconds == 0
    string_result = "#{string_result}#{seconds} second"
    string_result = "#{string_result}s" unless seconds == 1
  end
  return string_result
end

def create_email(params)
  # params = :name (send_to_name), :address (send_to_address), :rsync_result, 
  #          :email_server (email_server), :sender_name (send_from_name),
  #          :sender_address (send_from_address), :backup_start_time
  #          :snapshot_result, :rsync_error, :snapshot_error

  email_subject = 'Disk-to-disk backup results'

  email_template = File.read(EMAIL_TEMPLATE_LOCATION)
  email_eruby = Erubis::FastEruby.new(email_template)
  erb_binding = { :rsync_result => params[:rsync_result], :snapshot_result => params[:snapshot_result], :backup_time => determine_time(params[:backup_start_time]), :rsync_error => params[:rsync_error], :snapshot_error => params[:snapshot_error], :number_backups => all_snaps.count, oldest_backup_time => oldest_snap_time }
  email_markdown = Markdown.new(email_eruby.result(erb_binding))

  # return this object
  Mail.new do
    from "#{params[:sender_name]} <#{params[:sender_address]}>"
    to "#{params[:name]} <#{params[:address]}>"
    subject email_subject
    delivery_method :smtp, { :address => params[:email_server], :enable_starttls_auto => false }
    text_part do
      body email_markdown.text
    end
    html_part do
      content_type 'text/html; charset=UTF-8'
      body email_markdown.to_html
    end
  end

end
