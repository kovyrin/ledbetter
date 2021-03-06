
require 'socket'
require 'uri'
require 'nagiosharder'

nagios_user = ENV['NAGIOS_USER'] || raise('missing NAGIOS_USER')
nagios_pass = ENV['NAGIOS_PASS'] || raise('missing NAGIOS_PASS')
nagios_url  = ENV['NAGIOS_URL'] || raise('missing NAGIOS_URL')

# connect to remote carbon socket
begin
  carbon_url = URI.parse(ENV['CARBON_URL'])
rescue
  raise "missing CARBON_URL, e.g. carbon://localhost:2003"
end
begin
  carbon = TCPSocket.new(carbon_url.host, carbon_url.port)
rescue
  raise "unable to connect to CARBON_URL at #{carbon_url}"
end

# connect to Nagios server
begin
  site = NagiosHarder::Site.new(nagios_url, nagios_user, nagios_pass)
rescue
  raise "unable to connect to NAGIOS_URL at #{nagios_url}"
end

# see if we have a custom metrics prefix
carbon_prefix = ENV['CARBON_PREFIX'] || 'nagios.problems'

# grab current timestamp
time = Time.now.to_i

# fetch our service problem counts by type
critical = site.service_status(:service_status_types => ['critical']).count
warning = site.service_status(:service_status_types => ['warning']).count
unknown = site.service_status(:service_status_types => ['unknown']).count
all = critical + warning + unknown

carbon.puts "#{carbon_prefix}.all #{all} #{time}"
carbon.puts "#{carbon_prefix}.critical #{critical} #{time}"
carbon.puts "#{carbon_prefix}.warning #{warning} #{time}"
carbon.puts "#{carbon_prefix}.unknown #{unknown} #{time}"

if ENV['VERBOSE'].to_i.eql?(1)
  puts "#{carbon_prefix}.all #{all} #{time}"
  puts "#{carbon_prefix}.critical #{critical} #{time}"
  puts "#{carbon_prefix}.warning #{warning} #{time}"
  puts "#{carbon_prefix}.unknown #{unknown} #{time}"
end

# fetch our service problem counts by group
site.servicegroups_summary.each do |name, group|
  service_problems = group['service_status_counts']['critical'].to_i +
                     group['service_status_counts']['warning'].to_i +
                     group['service_status_counts']['unknown'].to_i
  carbon.puts "#{carbon_prefix}.servicegroups.#{group['group']} #{service_problems} #{time}"
  puts "#{carbon_prefix}.servicegroups.#{group['group']} #{service_problems} #{time}" if ENV['VERBOSE'].to_i.eql?(1)
end

# fetch our host problem counts by group
site.hostgroups_summary.each do |name, group|
  carbon.puts "#{carbon_prefix}.hostgroups.#{group['group']} #{group['host_status_counts']['down']} #{time}"
  puts "#{carbon_prefix}.hostgroups.#{group['group']} #{group['host_status_counts']['down']} #{time}" if ENV['VERBOSE'].to_i.eql?(1)
end
