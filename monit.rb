#!/usr/bin/env ruby
require 'awesome_print'

SERVER  = %x[hostname]
EMAIL   = 'dolgov.ra@gmail.com'
SUBJECT = "[#{SERVER}] Services are not available"

@services = {
  dns:        { state: 0, port: 53,     process: 'named'      },
  dhcp:       { state: 0, port: 67,     process: 'dhcpd'      },
  sshd:       { state: 0, port: 33,     process: 'sshd'       },
  web:        { state: 0, port: 80,     process: 'nginx'      },
  mysql:      { state: 0, port: 3306,   process: 'mysqld'     },
  pgsql:      { state: 0, port: 5432,   process: 'postgres'   },
  openvpn:    { state: 0, port: 31337,  process: 'openvpn'    },
  memcached:  { state: 0, port: 11211,  process: 'memcached'  },
  tor:        { state: 0, port: 9050,   process: 'tor'        },
  motion:     { state: 0, port: 58081,  process: 'motion'     },
  prosody:    { state: 0, port: 5222,   process: 'lua5.1'     }
}

@body = nil
@df_hash = {}

def is_port_open?(port)
  if %x[netstat -nlp | grep ':#{port} ' | wc -l].to_i > 0
    true
  else
    false
  end
end

def is_process_run?(name)
  if %x[pidof #{name} | wc -l].to_i > 0
    true
  else
    false
  end
end

def check_services
  @services.each do |name, hash|
    hash.each do |key,value|
      case key
      when :port
        @services[name][:state] += 1 if is_port_open? value
      when :process
        @services[name][:state] += 1 if is_process_run? value
      end
    end
  end
end

def check_space
  df = %x[df --output=source,pcent | egrep '(/dev|rootfs)']
  df.split("\n").each do |drive|
    dev,used = drive.split
    @df_hash[dev] = used.chomp('%')
  end
end

def check_load
  load = %x[uptime|awk '{print $NF}'].chop.gsub(',', '.').to_f
  ap load
  if load > %x[grep processor /proc/cpuinfo |wc -l].to_f
      msg = "System load for 15 minutes too high #{load.to_s}"
      @body.nil? ? @body = msg : @body += "\n#{msg}"
  end
end

def make_body
  @services.each do |name, hash|
    if hash[:state] < 2
      @body.nil? ? @body = name.to_s : @body += "\n#{name.to_s}"
    end
  end

  @df_hash.each do |dev,used|
    if used.to_i > 90
      msg = "#{dev} has only #{100 - used.to_i}% free"
      @body.nil? ? @body = msg : @body += "\n#{msg}"
    end
  end
end

def send_email
  if !@body.nil?
    %x[echo '#{@body}' | mailx -s '#{SUBJECT}' #{EMAIL}]
  end
end

check_services
make_body
check_space
send_email
