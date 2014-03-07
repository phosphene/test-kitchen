#
# Author:: Andrew Crump (<andrew@kotirisoftware.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
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

module TestKitchen

  module Helpers

    def any_platform_torn_down?
      ! platform_boot_count.reject{|bc| bc[1] <= 1}.empty?
    end

    def available_platforms
      @platforms
    end

    def assert_only_platforms_converged(platform_prefixes)
      expected_platforms.each do |platform|
        if platform_prefixes.any?{|p| platform.start_with?("#{p}-")}
          assert(converged?(platform, 'example'),
            "Expected platform '#{platform}' to have been converged.")
        else
          refute(converged?(platform, 'example'),
            "Expected platform '#{platform}' not to have been converged.")
        end
      end
    end

    # Setup a cookbook project that uses test-kitchen for integration testing
    def chef_cookbook(options = {})
      options = {:type => :real_world, :missing_config => false, :setup => true,
        :recipes => []}.merge(options)
      case options[:type]
        when :real_world
          if options[:missing_config]
            options[:name] = 'emacs'
            clone_cookbook_repository('opscode-cookbooks', 'emacs', '96d1026')
            cd 'emacs'
          else
            options[:name] = 'erlang'
            clone_cookbook_repository('opscode-cookbooks', 'erlang', '0e910c5')
            add_gem_file('erlang')
            add_test_setup_recipe('erlang', 'erlang_test')
          end
        when :real_world_testless
          clone_cookbook_repository('opscode-cookbooks', 'vim', '88e8d01')
        when :real_world_testless_dir
          clone_cookbook_repository('opscode-cookbooks', 'vim', '88e8d01', 'cookbook-vim')
        when :newly_generated
          generate_new_cookbook(options[:name], options[:path], options[:recipes])
          add_platform_metadata(options[:name], options[:supports_type], options[:path]) if options[:supports_type]
          add_gem_file(options[:name], options[:path])
          add_test_setup_recipe(options[:name], "#{options[:name]}_test", options[:path]) if options[:setup]
        else
          fail "Unknown type: #{options[:type]}"
      end
      introduce_syntax_error(options[:name]) if options[:malformed]
      introduce_correctness_problem(options[:name]) if options[:lint_problem] == :correctness
      introduce_style_problem(options[:name]) if options[:lint_problem] == :style
    end

    def configuration_recipe(cookbook_name, test_cookbook, configuration)
      write_file "#{cookbook_name}/test/kitchen/cookbooks/#{test_cookbook}/recipes/#{configuration}.rb", %q{
        Chef::Log.info("This is a configuration recipe.")
      }
    end

    def converged?(platform, recipe)
      converges = all_output.split(/Importing base box.*\n */)
      converges.any? do |converge|
        converge.start_with?("[#{platform}]") &&
          converge.match(/Run List is .*#{Regexp.escape(recipe)}/)
      end
    end

    def expected_platforms
      ['centos-6.3', 'ubuntu-12.04']
    end

    def list_platforms
      run_simple(unescape("bundle exec kitchen platform list"))
      @platforms = all_output.split("\n").map(&:lstrip)
    end

    def platform_boots
      all_output.lines.grep(/Booting VM.../).map{|line| line.match(/^\[([^\]]+)\]/)[1]}
    end

    def platform_boot_count
      platform_boots.uniq.map {|e| [e, (platform_boots.select {|ee| ee == e}).size]}
    end

    def ruby_project
      run_simple('git clone --quiet https://github.com/jtimberman/mixlib-shellout.git')
      cd('mixlib-shellout')
      run_simple('git checkout --quiet 933784a3240d488cfbf79b5a9b8ecb89ef2cb44f')
      run_simple('sed -i -e "682,692d" ./spec/mixlib/shellout_spec.rb')
      cd '..'
    end

    def define_integration_tests(options={})
      options = {
        :project_type => 'cookbook',
        :name => 'erlang',
        :configurations => []
      }.merge(options)

      case options[:project_type]
        when "project"
          options[:name] = 'mixlib-shellout'
          write_file "#{File.join(options[:name], 'test', 'kitchen', 'Kitchenfile')}", %Q{
            integration_test "#{options[:name]}" do
              language 'ruby'
              runner 'vagrant'
              runtimes ['1.9.3']
              install 'bundle install --without kitchen'
              script 'bundle exec rspec spec'
              run_list_extras ['mixlib-shellout_test::default']
            #{'end' unless options[:malformed]}
          }
          cd options[:name]
        when "cookbook"
          # TODO: Template this properly
          dsl = %Q{cookbook "#{options[:name]}" do\n}
          options[:configurations].each do |configuration|
            dsl << %Q{  configuration "#{configuration}"\n}
          end
          if options[:name] == 'erlang'
            dsl << %Q{run_list_extras ['erlang_test::default']\n}
          end
          dsl << 'end' unless options[:malformed]
          write_file "#{options[:name]}/test/kitchen/Kitchenfile", dsl
          cd options[:name]
        else
          fail "Unrecognized project type: #{options[:project_type]}"
      end
    end

    def run_integration_tests(options = {})
      options = {:times => 1, :teardown => true}.merge(options)
      begin
        run_simple(unescape("bundle install"))
        options[:times].times do
          cmd = 'bundle exec kitchen test'
          cmd << ' --teardown' if options[:teardown]
          run_simple(unescape(cmd), false)
        end
      rescue
        raise
      ensure
        puts all_output
      end
    end

    def scaffold_tests(cookbook_name)
      cd cookbook_name
      run_simple(unescape("bundle install"))
      run_simple(unescape("bundle exec kitchen init"))
    end

    def cookbook_project_name_metadata?
      kf = File.join(File.expand_path(current_dir), 'test', 'kitchen', 'Kitchenfile')
      check_file_content(kf, 'cookbook "vim" do', true)
    end

    def kitchenfile_error_shown?
      !! (all_output =~ /Your Kitchenfile could not be loaded. Please check it for errors./)
    end

    def lint_correctness_error_shown?
      !! (all_output =~ /Your cookbook had lint failures./)
    end

    def syntax_error_shown?
      !! (all_output =~ %r{FATAL: Cookbook file recipes/default.rb has a ruby syntax error})
    end

    def tests_run?
      !! (all_output =~ /([0-9]+ tests, [0-9]+ assertions, [0-9]+ failures, [0-9]+ errors|[0-9]+ examples, 0 failures)/)
    end

    def unrecognized_platform_warning_shown?(platform_name)
      !! (all_output =~ %r{Cookbook metadata specifies an unrecognized platform that will not be tested: #{Regexp.escape(platform_name)}})
    end

    private

    def clone_cookbook_repository(organization, cookbook_name, sha, dirname = '')
      run_simple("git clone --quiet git://github.com/#{organization}/#{cookbook_name}.git #{dirname}")
      working_dir = dirname.length > 0 ? dirname : cookbook_name
      cd(working_dir)
      run_simple("git checkout --quiet #{sha}")
      cd '..'
    end

    def introduce_syntax_error(cookbook_name)
      append_to_file("#{cookbook_name}/recipes/default.rb", %q{
        end # Bang!
      })
    end

    def introduce_correctness_problem(cookbook_name)
      append_to_file("#{cookbook_name}/recipes/default.rb", %q{
        # This resource should trigger a FC006 warning
        directory "/var/lib/foo" do
          owner "root"
          group "root"
          mode 644
          action :create
        end
      })
    end

    def introduce_style_problem(cookbook_name)
      append_to_file("#{cookbook_name}/recipes/default.rb", %q{
        path = "/var/lib/foo"
        directory "#{path}" do
          action :create
        end
      })
    end

    def add_gem_file(cookbook_name, path='.')
      gems = %w{cucumber minitest}
      gems += %w{nokogiri httparty} if cookbook_name == 'apache2'
      write_file "#{path}/#{cookbook_name}/test/Gemfile", %Q{
        source :rubygems

        #{gems.map{|g| "gem '#{g}'"}.join("\n")}

        group(:kitchen) do
          gem "test-kitchen", :path => '../../../..'
        end
      }
    end

    def add_platform_metadata(cookbook_name, supports_type, path='.')
      supports = case supports_type
        when :literal then "supports 'ubuntu'"
        when :wordlist then %q{
          %w{ubuntu centos}.each do |os|
            supports os
          end
        }
        when :includes_unrecognized then %q{
          %w{ubuntu beos centos}.each do |os|
            supports os
          end
        }
        else fail "Unrecognized supports_type: #{supports_type}"
      end
      append_to_file("#{path}/#{cookbook_name}/metadata.rb", "#{supports}\n")
    end

    def add_test_setup_recipe(cookbook_name, test_cookbook, path='.')
      write_file "#{path}/#{cookbook_name}/test/kitchen/cookbooks/#{test_cookbook}/recipes/setup.rb", %q{
        case node.platform
          when 'ubuntu'
            %w{libxml2 libxml2-dev libxslt1-dev}.each do |pkg|
              package pkg do
                action :install
              end
            end
          when 'centos'
            %w{gcc make ruby-devel libxml2 libxml2-devel libxslt libxslt-devel}.each do |pkg|
              package pkg do
                action :install
              end
            end
          end

        package "curl" do
          action :install
        end
      }
    end

    module CommandLine

      def assert_command_banner_present(subcommand)
        all_output.must_match /^kitchen #{Regexp.escape(subcommand)} \(options\)/
      end

      def assert_correct_subcommands_shown
        subcommands_shown(all_output).must_equal expected_subcommands
      end

      def assert_option_present(flag, description)
        displayed_options.must_include [flag, description]
      end

      def command_help(subcommand)
        run_simple(unescape("bundle exec kitchen #{subcommand} --help"))
        @subcommand = subcommand
      end

      def current_subcommand
        @subcommand
      end

      def displayed_options
        all_output.split("\n").drop(1).map do |option|
          option.split(/   /).reject{|t| t.empty?}.map{|o| o.strip}
        end
      end

      def expected_subcommands
        %w{destroy init platform project ssh status test}
      end

      def generate_new_cookbook(name, path, recipes=[])
        run_simple("knife cookbook create -o #{path} #{name}")
        recipes.each do |recipe|
          write_file "#{path}/#{name}/recipes/#{recipe}.rb", %q{
            Chef::Log.info("This is a cookbook recipe.")
          }
        end
      end

      def option_flags
        displayed_options.map{|o| o.first}.compact.select do |o|
          o.start_with?('-')
        end.map{|o| o.split('--')[1].split(' ').first}
      end

      def subcommands_shown(output)
        output.split("\n").select{|line|line.start_with? 'kitchen '}.map do |line|
          line.split(' ')[1]
        end.sort
      end

    end
  end
end

World(TestKitchen::Helpers)
World(TestKitchen::Helpers::CommandLine)
