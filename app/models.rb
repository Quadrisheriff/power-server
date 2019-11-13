# frozen_string_literal: true

#==============================================================================
# Copyright (C) 2019-present Alces Flight Ltd.
#
# This file is part of Power Server.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# Power Server is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with Flight Cloud. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on Power Server, please visit:
# https://github.com/openflighthpc/metal-server
#===============================================================================

require 'hashie'

class Topology < Hashie::Trash
  include Hashie::Extensions::IgnoreUndeclared
  include Hashie::Extensions::Coercion

  # Converts the nodes hash into Node objects
  property :nodes, required: true, transform_with: ->(node_hashes) do
    node_hashes.each_with_object(Hashie::Mash.new) do |(id, attr), memo|
      memo[id] = Node.new(id: id, **attr)
    end
  end
  coerce_key :nodes, Hash[Symbol => Hash]

  # Converts the platform hash into Platform Objects
  property :platforms, required: true, transform_with: ->(plat_hashes) do
    plat_hashes.each_with_object(Hashie::Mash.new) do |(name, attr), memo|
      memo[id] = Platform.new(name: name, **attr)
    end
  end
  coerce_key :Platform, Hash[Symbol => Hash]
end

class Node < Hashie::Mash
  def initialize(*_)
    super
    raise ArgumentError, <<~ERROR unless id?
      The property 'id' is required for #{self.class}
    ERROR
  end
end

class Platform < Hashie::Dash
  include Hashie::Extensions::IgnoreUndeclared

  property  :name,    required: true
  property  :on,      required: true
  property  :off,     required: true
  property  :reboot,  required: true
  property  :status,  required: true
end

