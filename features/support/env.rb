<<<<<<< HEAD
# Set up the environment for testing
require 'aruba/cucumber'
require 'aruba/in_process'
require 'aruba/spawn_process'
require 'kitchen'
require 'kitchen/cli'

class ArubaHelper
  def initialize(argv, stdin=STDIN, stdout=STDOUT, stderr=STDERR, kernel=Kernel)
    @argv, @stdin, @stdout, @stderr, @kernel = argv, stdin, stdout, stderr, kernel
  end

  def execute!
    $stdout = @stdout
    $stdin = @stdin

    kitchen_cli = Kitchen::CLI
    kitchen_cli.start(@argv)
    @kernel.exit(0)
  end
end

Before do
  @aruba_timeout_seconds = 15
  @cleanup_dirs = []

  Aruba::InProcess.main_class = ArubaHelper
  Aruba.process = Aruba::InProcess
end

Before('@spawn') do
  Aruba.process = Aruba::SpawnProcess
end

After do |s|
  # Tell Cucumber to quit after this scenario is done - if it failed.
  # This is useful to inspect the 'tmp/aruba' directory before any other
  # steps are executed and clear it out.
  Cucumber.wants_to_quit = true if s.failed?

  # Restore environment variables to their original settings, if they have
  # been saved off
  ENV.keys.select { |key| key =~ /^_CUKE_/ }.each do |backup_key|
    ENV[backup_key.sub(/^_CUKE_/, '')] = ENV.delete(backup_key)
  end

  @cleanup_dirs.each { |dir| FileUtils.rm_rf(dir) }
end

def backup_envvar(key)
  ENV["_CUKE_#{key}"] = ENV[key]
end

def restore_envvar(key)
  ENV[key] = ENV.delete("_CUKE_#{key}")
end

def unbundlerize
  keys = %w[BUNDLER_EDITOR BUNDLE_BIN_PATH BUNDLE_GEMFILE RUBYOPT]

  keys.each { |key| backup_envvar(key) ; ENV.delete(key) }
  yield
  keys.each { |key| restore_envvar(key) }
=======
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

require 'aruba/cucumber'

require 'minitest/spec'

World(MiniTest::Assertions)
MiniTest::Spec.new(nil)

Before do
  @aruba_timeout_seconds = 60 * 60
>>>>>>> d042cbc92b823978d09bb8d341a527c09ce3c68f
end
