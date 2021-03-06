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
# https://github.com/openflighthpc/power-server
#===============================================================================

class BaseCommandSerializer
  include JSONAPI::Serializer

  attributes :action
  attribute(:node_name) { object.id }
  attribute(:platform) { object.platform.name }

  attribute(:missing) { object.node.missing }
end

class CommandSerializer < BaseCommandSerializer
  attribute(:success) { object.exit_code == 0 }
end

class StatusCommandSerializer < BaseCommandSerializer
  attribute(:success) do
    [0, object.platform.status_off_exit_code].include?(object.exit_code)
  end

  attribute(:running) do
    next true if object.exit_code == 0
    next false if object.exit_code == object.platform.status_off_exit_code
  end
end

class NodeSerializer
  include JSONAPI::Serializer

  attributes :name
end

class GroupRecordSerializer
  include JSONAPI::Serializer

  def id
    object.name
  end

  def type
    'groups'
  end

  attributes :name
  attribute(:nodes) { object.nodes.map(&:name) }
end

