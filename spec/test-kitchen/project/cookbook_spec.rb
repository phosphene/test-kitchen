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

require 'test-kitchen'

module TestKitchen

  module Project
    describe Cookbook do
      describe "#each_build" do
        it "yields only supported platforms" do
          cookbook = Cookbook.new('example')
          cookbook.supported_platforms = %w{ubuntu centos}
          actual_matrix = []
          cookbook.each_build(%w{beos-5.0 centos-5.0 centos-6.2}) do |platform,configuration|
            actual_matrix << [platform, configuration]
          end
          actual_matrix.must_equal([
            ['centos-5.0', cookbook],
            ['centos-6.2', cookbook]
          ])
        end
        it "yields all platforms if the cookbook does not specify the supported platforms" do
          cookbook = Cookbook.new('example')
          cookbook.supported_platforms = []
          actual_matrix = []
          cookbook.each_build(%w{beos-5.0 centos-5.0 centos-6.2}) do |platform,configuration|
            actual_matrix << [platform, configuration]
          end
          actual_matrix.must_equal([
            ['beos-5.0', cookbook],
            ['centos-5.0', cookbook],
            ['centos-6.2', cookbook]
          ])
        end

      end
    end
    describe "#extract_supported_platforms" do
      let(:cookbook) { Cookbook.new('example') }
      it "raises if no metadata is provided" do
        lambda { cookbook.extract_supported_platforms }.must_raise ArgumentError
      end
      it "raises if the metadata is nil" do
        lambda { cookbook.extract_supported_platforms(nil) }.must_raise ArgumentError
      end
      it "returns an empty if the metadata does not parse" do
        cookbook.extract_supported_platforms(%q{
          <%= not_ruby_code %>
        }).must_be_empty
      end
      it "returns an empty if the metadata does not specify platforms" do
        cookbook.extract_supported_platforms(%q{
          maintainer       "Example Person"
          maintainer_email "example@example.org"
          license          "All rights reserved"
          description      "Installs/Configures example"
          long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
          version          "0.0.1"
        }).must_be_empty
      end
      it "returns the name of the supported platforms" do
        cookbook.extract_supported_platforms(%q{
          maintainer       "Example Person"
          maintainer_email "example@example.org"
          license          "All rights reserved"
          description      "Installs/Configures example"
          long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
          version          "0.0.1"
          supports         "ubuntu"
          supports         "centos"
          depends          "java"
        }).must_equal(%w{ubuntu centos})
      end
      it "returns the name of supported platforms when versions are specified" do
        cookbook.extract_supported_platforms(%q{
          maintainer       "Example Person"
          maintainer_email "example@example.org"
          license          "All rights reserved"
          description      "Installs/Configures example"
          long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
          version          "0.0.1"
          supports         "ubuntu"
          supports         "centos", ">= 6.0"
          depends          "java"
        }).must_equal(%w{ubuntu centos})
      end
      it "returns the name of the supported platforms for a word list" do
        cookbook.extract_supported_platforms(%q{
          maintainer       "Example Person"
          maintainer_email "example@example.org"
          license          "All rights reserved"
          description      "Installs/Configures example"
          long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
          version          "0.0.1"
          %w{centos ubuntu debian}.each do |os|
            supports os
          end
          %w{java}.each do |cookbook|
            depends cookbook
          end
        }).must_equal(%w{centos ubuntu debian})
      end
      it "returns the name of the supported platforms" do
        cookbook.extract_supported_platforms(%q{
          maintainer       "Example Person"
          maintainer_email "example@example.org"
          license          "All rights reserved"
          description      "Installs/Configures example"
          long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
          version          "0.0.1"
          supports         "ubuntu"
          supports         "centos"
        }).must_equal(%w{ubuntu centos})
      end
    end
    describe "#non_buildable_platforms" do
      let(:cookbook) { Cookbook.new('example') }
      it "returns empty if all platforms can be built" do
        cookbook.supported_platforms = 'centos', 'ubuntu'
        cookbook.non_buildable_platforms(
          ['centos-6.2', 'ubuntu-10.04']).must_be_empty
      end
      it "returns the platforms that are not supported for builds" do
        cookbook.supported_platforms = 'centos', 'ubuntu', 'beos'
        cookbook.non_buildable_platforms(
          ['centos-6.2', 'ubuntu-10.04']).must_equal(['beos'])
      end
    end
    describe "#language" do
      let(:cookbook) { Cookbook.new('example') }
      it "returns the language when asked" do
        cookbook.language.must_equal 'ruby'
      end
    end
    describe "#run_list" do
      let(:cookbook) { Cookbook.new('example') }
      it "includes minitest-handler cookbook in the run_list as the last entry" do
        cookbook.run_list.last.must_equal 'recipe[minitest-handler]'
      end
    end
    describe "#preflight_command" do
      let(:cookbook) { Cookbook.new('example') }
      it "returns nil if linting is disabled" do
        cookbook.lint = false
        refute cookbook.preflight_command
      end
      it "returns two commands if linting is enabled" do
        cookbook.root_path = 'cookbooks/example'
        cookbook.preflight_command.split(" && ").size.must_equal 2
      end
      it "includes the command to check the cookbook is well-formed" do
        cookbook.root_path = 'cookbooks/example'
        cookbook.preflight_command.split(" && ").first.must_equal "knife cookbook test -o cookbooks/example/.. example"
      end
      describe "lint options" do
        let(:lint_cmd) do
          cookbook.root_path = 'cookbooks/example'
          cookbook.preflight_command.split(" && ").last
        end
        it "includes the command to lint the cookbook" do
          lint_cmd.must_match /^foodcritic/
        end
        it "fails for any correctness warning except undeclared metadata dependencies" do
          lint_cmd.must_equal "foodcritic -f ~FC007 -f correctness cookbooks/example"
        end
        it "includes ignored tags to the lint command" do
          cookbook.lint(:ignore => %w{FC001 FC003})
          lint_cmd.must_equal "foodcritic -f ~FC007 -f correctness -t ~FC001 -t ~FC003 cookbooks/example"
        end
      end
      describe "#data_bags_path" do
        let(:cookbook) { Cookbook.new('bar') }
        it "is set to test/kitchen/data_bags by default" do
          cookbook.data_bags_path.must_equal cookbook.root_path.join('test/kitchen/data_bags').to_s
        end
        it "can be set to /tmp" do
          cookbook.data_bags_path = '/tmp'
          cookbook.data_bags_path.must_equal '/tmp'
        end
      end
    end
  end
end
