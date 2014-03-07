<<<<<<< HEAD
# -*- encoding: utf-8 -*-
#
# Author:: Fletcher Nichol (<fnichol@nichol.ca>)
#
# Copyright (C) 2012, Fletcher Nichol
=======
#
# Author:: Andrew Crump (<andrew@kotirisoftware.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
>>>>>>> d042cbc92b823978d09bb8d341a527c09ce3c68f
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
<<<<<<< HEAD
#    http://www.apache.org/licenses/LICENSE-2.0
=======
#     http://www.apache.org/licenses/LICENSE-2.0
>>>>>>> d042cbc92b823978d09bb8d341a527c09ce3c68f
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
<<<<<<< HEAD

gem 'minitest'

require 'simplecov'
SimpleCov.adapters.define 'gem' do
  command_name 'Specs'

  add_filter '.gem/'
  add_filter '/spec/'
  add_filter '/lib/vendor/'

  add_group 'Libraries', '/lib/'
end
SimpleCov.start 'gem'

require 'fakefs/safe'
require 'minitest/autorun'
require 'mocha/setup'
require 'tempfile'

# Nasty hack to redefine IO.read in terms of File#read for fakefs
class IO
  def self.read(*args)
    File.open(args[0], "rb") { |f| f.read(args[1]) }
  end
end
=======
#

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'minitest/autorun'
require 'minitest/spec'

SimpleCov.at_exit do
  SimpleCov.result.format!
  if SimpleCov.result.covered_percent < 66
    warn "Coverage is slipping: #{SimpleCov.result.covered_percent.to_i}%"
  end
end

require_relative '../lib/test-kitchen'
>>>>>>> d042cbc92b823978d09bb8d341a527c09ce3c68f
