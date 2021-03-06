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

require 'hashie'

class SymbolizedMash < ::Hashie::Mash
  include Hashie::Extensions::Mash::SymbolizeKeys
end

class Topology < Hashie::Trash
  module Cache
    class << self
      delegate_missing_to :cache

      def cache
        @cache ||= Topology.new(SymbolizedMash.load(path)).tap do |top|
          if Figaro.env.remote_url
            top.dynamic_nodes_cluster = Figaro.env.remote_cluster
          end
        end
      end

      def path
        Figaro.env.topology_config
      end
    end
  end

  include Hashie::Extensions::Dash::Coercion

  attr_reader :dynamic_nodes

  def nodes
    dynamic_nodes || static_nodes || raise('Could not load the nodes data')
  end

  def dynamic_nodes_cluster=(cluster)
    raise <<~ERROR.squish if static_nodes
      An upstream OpenFlightHPC/NodeattrServer can not be integrated with
      static nodes. Please remove the `static_nodes` key from the topology
      config and try again.
    ERROR
    @dynamic_nodes = Nodes::DynamicNodes.new(cluster)
  end

  # Converts the static_nodes hash into StaticNodes object
  property  :static_nodes, coerce: Hash[Symbol => Hash],
            transform_with: ->(h) { Nodes::StaticNodes.new(h) }

  # Converts the platform hash into Platform Objects
  property  :platforms, required: true, coerce: Hash[Symbol => Hash],
            transform_with: ->(h) { Platforms.new(h) }
end

module Nodes
  class StaticNodes < Hashie::Mash
    def initialize(**node_hash)
      nodes = node_hash.map do |name, attr|
        node = Node.new name: name,
                        platform: attr.delete(:platform),
                        attributes: attr.merge(name: name)
        [name, node]
      end
      super(nodes.to_h)
    end

    def [](key)
      super(key) || Node.new(name: key, missing: true)
    end

    # Dummy method that allows StaticNodes to be used interchangeable DynamicNodes
    def where_group(_)
      []
    end

    def all_groups
      []
    end

    # Return the Nodes so they can be serialized
    def to_a
      values
    end
  end

  class DynamicNodes < Hashie::Rash
    attr_reader :__cluster__

    def self.coerce_record(record)
      Node.new(
        name: record.name,
        platform: record.params[:platform],
        attributes: record.params
      )
    end

    def initialize(cluster)
      @__cluster__ = cluster
      super({
        /\A[\w-]+\Z/ => ->(match) do
          begin
            record = NodeRecord.find("#{__cluster__}.#{match.to_s}").first
            self.class.coerce_record(record)
          rescue JsonApiClient::Errors::NotFound
            Node.new(name: match.to_s, missing: true)
          end
        end
      })
    end

    def where_group(group)
      begin
        NodeRecord.where(group_id: "#{__cluster__}.#{group}")
                  .all
                  .map { |r| self.class.coerce_record(r) }
      rescue JsonApiClient::Errors::NotFound
        []
      end
    end

    # Fetch the available upstream nodes
    def to_a
      NodeRecord.where(cluster_id: ".#{__cluster__}").all.map { |r| self.class.coerce_record(r) }
    end

    def all_groups
      GroupRecord.includes(:nodes).where(cluster_id: ".#{__cluster__}").all
    end
  end
end

class Node < Hashie::Dash
  include Hashie::Extensions::Dash::Coercion

  def initialize(*_)
    super
    attributes[:name] = name
  end

  property :name,       required: true
  property :missing,    default: false
  property :platform,   default: :missing
  property :attributes, default: {}, coerce: Hashie::Mash

  def id
    name
  end

  def missing?
    missing
  end
end

class Platforms < Hashie::Mash
  def initialize(**platform_hash)
    platforms = platform_hash.merge(missing: {}).map do |name, attr|
      [name, Platform.new(name: name, **attr)]
    end
    super(platforms.to_h)
  end

  def [](key)
    super(key) || super(:missing)
  end
end

class Platform < Hashie::Dash
  include Hashie::Extensions::Dash::Coercion

  property  :name,      required: true
  property  :variables, default: []
  property  :power_on,  default: 'exit 1'
  property  :power_off, default: 'exit 1'
  property  :restart,   default: 'exit 1'
  property  :status,    default: 'exit 1'
  property  :status_off_exit_code,  default: 111
end

