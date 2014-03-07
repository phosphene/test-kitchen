#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
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
  module Project
    class Cookbook < Ruby

      include CookbookCopy
      include SupportedPlatforms

      attr_writer :lint
      attr_writer :supported_platforms
      attr_writer :data_bags_path

      def lint(arg=nil)
        set_or_return(:lint, arg, {:default => true})
      end

      def run_list
        super + ['recipe[minitest-handler]']
      end

      def preflight_command(cmd = nil)
        return nil unless lint
        parent_dir = File.join(root_path, '..')
        ignore_tags = ''
        if lint.respond_to?(:has_key?) && lint[:ignore].respond_to?(:join)
          ignore_tags = " -t ~#{lint[:ignore].join(' -t ~')}"
        end
        set_or_return(:preflight_command, cmd, :default =>
          "knife cookbook test -o #{parent_dir} #{name}" +
          " && foodcritic -f ~FC007 -f correctness#{ignore_tags} #{root_path}")
      end

      def data_bags_path(path = nil)
        set_or_return(:data_bags_path, path,
          { :default => root_path.join('test/kitchen/data_bags').to_s })
      end

      def script(arg=nil)
        set_or_return(:script, arg, :default =>
          %Q{if [ -d "features" ]; then bundle exec cucumber -t @#{tests_tag} features; fi})
      end

      def install_command(runtime=nil)
        super(runtime, File.join(guest_test_root, 'test'))
      end

      def test_command(runtime=nil)
        super(runtime, File.join(guest_test_root, 'test'))
      end

      def supported_platforms
        @supported_platforms ||= extract_supported_platforms(
          File.read(File.join(root_path, 'metadata.rb')))
      end

      def non_buildable_platforms(platform_names)
        supported_platforms.sort - platform_names.map do |platform|
          platform.split('-').first
        end.sort.uniq
      end

      def each_build(platforms, active_config=nil, &block)
        if supported_platforms.empty?
          super(platforms, active_config, &block)
        else
          super(platforms.select do |platform|
            supported_platforms.any? do |supported|
              platform.start_with?("#{supported}-")
            end
          end, active_config, &block)
        end
      end

      def cookbook_path(root_path, tmp_path)
        @cookbook_path ||= copy_cookbook_under_test(root_path, tmp_path)
      end

    end
  end
end
