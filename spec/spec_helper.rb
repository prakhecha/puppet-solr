require 'puppetlabs_spec_helper/module_spec_helper'

fixture_path = File.expand_path(File.join(__FILE__, '..', 'fixtures'))

RSpec.configure do |c|
  c.module_path = File.join(fixture_path, 'modules')
  c.manifest_dir = File.join(fixture_path, 'manifests')

  if c.files_to_run.detect { |f| f.match(/system/) }
    require 'serverspec'
    require 'pathname'
    require 'net/ssh'

    include Serverspec::Helper::Ssh
    include Serverspec::Helper::DetectOS

    if ENV['ASK_SUDO_PASSWORD']
      require 'highline/import'
      c.sudo_password = ask("Enter sudo password: ") { |q| q.echo = false }
    else
      c.sudo_password = ENV['SUDO_PASSWORD']
    end

    c.before :all do
      block = self.class.metadata[:example_group_block]
      if RUBY_VERSION.start_with?('1.8')
        file = block.to_s.match(/.*@(.*):[0-9]+>/)[1]
      else
        file = block.source_location.first
      end
      host  = File.basename(Pathname.new(file).dirname)
      if c.host != host
        c.ssh.close if c.ssh
        c.host  = host
        options = Net::SSH::Config.for(c.host)
        user    = options[:user] || Etc.getlogin

        vagrant_up = `vagrant up default`
        config = `vagrant ssh-config default`
        if config != ''
          config.each_line do |line|
            if match = /HostName (.*)/.match(line)
              c.host = match[1]
            elsif  match = /User (.*)/.match(line)
              user = match[1]
            elsif match = /IdentityFile (.*)/.match(line)
              options[:keys] =  [match[1].gsub(/"/,'')]
            elsif match = /Port (.*)/.match(line)
              options[:port] = match[1]
            end
          end
        end

        c.ssh   = Net::SSH.start(c.host, user, options)
      end
    end

  end
end
