module Ironfan
  class Provider
    class ChefServer

      class Node < Ironfan::Provider::Resource
        delegate :[], :[]=, :add_to_index, :apply_expansion_attributes,
            :attribute, :attribute=, :attribute?, :automatic_attrs,
            :automatic_attrs=, :cdb_destroy, :cdb_save, :chef_environment,
            :chef_environment=, :chef_server_rest, :class_from_file,
            :construct_attributes, :consume_attributes,
            :consume_external_attrs, :consume_run_list, :cookbook_collection,
            :cookbook_collection=, :couchdb, :couchdb=, :couchdb_id,
            :couchdb_id=, :couchdb_rev, :couchdb_rev=, :create, :default,
            :default_attrs, :default_attrs=, :default_unless,
            :delete_from_index, :destroy, :display_hash, :each,
            :each_attribute, :each_key, :each_value, :expand!, :find_file,
            :from_file, :has_key?, :include_attribute, :index_id, :index_id=,
            :index_object_type, :key?, :keys,
            :load_attribute_by_short_filename, :load_attributes, :name, :node,
            :normal, :normal_attrs, :normal_attrs=, :normal_unless, :override,
            :override_attrs, :override_attrs=, :override_unless, :recipe?,
            :recipe_list, :recipe_list=, :reset_defaults_and_overrides, :role?,
            :run_list, :run_list=, :run_list?, :run_state, :run_state=, :save,
            :set, :set_if_args, :set_or_return, :set_unless, :drive, :tags,
            :to_hash, :update_from!, :validate, :with_indexer_metadata,
          :to => :adaptee

        def initialize(*args)
          super
          self.adaptee ||= Chef::Node.new
        end

        def to_display(style,values={})
          values["Chef?"] =     adaptee.nil? ? "no" : "yes"
          values
        end

        def save!(computer)
          prepare_from computer
          save
        end

        def create!(computer)
          prepare_from computer

          client = computer[:client]
          unless File.exists?(client.key_filename)
            raise("Cannot create chef node #{name} -- client #{@chef_client} exists but no client key found in #{client.key_filename}.")
          end
          ChefServer.post_rest("nodes", adaptee, :client => client)
        end

        def prepare_from(computer)
          organization =                Chef::Config.organization
          normal[:organization] =       organization unless organization.nil?

          server =                      computer.server
          chef_environment =            server.environment
          run_list.instance_eval        { @run_list_items = server.run_list }
          normal[:cluster_name] =       server.cluster_name
          normal[:facet_name] =         server.facet_name
          normal[:permanent] =          computer.permanent?
          normal[:volumes] =            {}
          computer.drives.each {|v| normal[:volumes][v.name] = v.node}
        end

        #
        # Discovery
        #
        def self.load!(computers)
          query = "name:#{computers.cluster.name}-*"
          ChefServer.search(:node,query) do |raw|
            next if raw.blank?
            node = Node.new
            node.adaptee = raw
            remember node
          end
        end

        def self.correlate!(computers)
          # FIXME: Computers.each
          computers.each do |computer|
            if recall? computer.server.fullname
              computer.node = recall computer.server.fullname
              computer.node['volumes'].each do |name,volume|
                computer.drive(name).node.merge! volume
              end
              computer.node.users << computer.object_id
            end
          end
        end

        def self.validate!(computers)
          # FIXME: Computers.each
          computers.each do |computer|
            next unless computer.node and not computer[:client]
            computer.node.bogus << :node_without_client
          end
        end

        #
        # Manipulation
        #
        def self.create!(computers)
          # FIXME: Computers.each
          computers.each do |computer|
            next if computer.node?
            node = Node.new
            node.name           computer.server.fullname
            node.create!        computer
            computer.node =     node
            remember            node
          end
        end

        def self.destroy!(computers)
          # FIXME: Computers.each
          computers.each do |computer|
            next unless computer.node?
            forget computer.node.name
            computer.node.destroy
            computer.delete(:node)
          end
        end

        def self.save!(computers)
          # FIXME: Computers.each
          temp = computers.values.select(&:node?)
          temp.each {|computer| computer.node.save! computer }
          computers
        end

      end

    end
  end
end
