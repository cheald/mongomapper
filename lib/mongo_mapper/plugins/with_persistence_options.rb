module MongoMapper
  module Plugins
    module Querying
      class DecoratedPluckyQuery
        attr_accessor :query_proxy

        def with(options = {})
          query_proxy.options = options
          @collection = query_proxy.collection
          self
        end

        def database
          query_proxy.database
        end
      end
    end

    module WithPersistenceOptions
      extend ActiveSupport::Concern

      module ClassMethods
        extend Forwardable

        def with(options = {})
          QueryProxy.new(self, options)
        end

        def query(options = {})
          QueryProxy.new(self).query(options)
        end
      end

      class QueryProxy
        include ::MongoMapper::Plugins::Querying::ClassMethods
        attr_reader :collection, :database

        def initialize(klass, options = {})
          @klass = klass
          self.options = options
        end

        def options=(options = {})
          case options
          when Hash
            db   = options.delete(:database) || options.delete(:db)
            coll = options.delete(:collection) || options.delete(:coll)
          when String
            db, coll = options.split("/", 2)
            db       = nil if db.blank?
            coll     = nil if coll.blank?
          when Array
            db, coll = *options
          else
            raise "#with takes either a hash ({db: 'foo', collection: 'bar'}) or string ('foo/bar')"
          end
          self.database   = db
          self.collection = coll
        end

        def query(options={})
          query = MongoMapper::Plugins::Querying::DecoratedPluckyQuery.new(collection, :transformer => transformer)
          query.query_proxy = self
          query.object_ids(object_id_keys)
          query.amend(options)
          query.model(@klass)
          query
        end

        def new(attributes = {})
          @klass.new(attributes).send(:override_connection_info, database, collection)
        end

        def method_missing(method, *args)
          @klass.send method, *args
        end

        private

        def transformer
          @transformer ||= lambda do |doc|
            loaded = @klass.send(:transformer).call(doc)
            loaded.send(:override_connection_info, database, collection)
            loaded
          end
        end

        def database=(database)
          case database
          when Mongo::DB
            @database = database
          when String, Symbol
            @database = @klass.connection[database.to_s]
          when nil
            @database = @klass.database
          else
            raise "Database must be a string, symbol, or Mongo::DB"
          end
        end

        def collection=(collection)
          case collection
          when Mongo::Collection
            @collection = collection
          when String, Symbol
            @collection = database[collection.to_s]
          when nil
            @collection = database[@klass.collection.name]
          else
            raise "Collection must be a string, symbol, or Mongo::Collection"
          end
        end
      end

      def collection
        @__collection || _root_document.class.collection
      end

      def database
        @__database || _root_document.class.database
      end

      def marshal_dump
        overrides = {}
        overrides[:__db_name] = @__database.name if @__database
        overrides[:__co_name] = @__collection.name if @__collection
        super.merge(overrides)
      end

      def marshal_load(args)
        db = args.delete :__db_name
        co = args.delete :__co_name
        if db || co
          proxy = QueryProxy.new(self.class, {:db => db, :collection => co})
          @__database = proxy.database if db
          @__collection = proxy.collection if co
        end
        super args
      end

      private

      def override_connection_info(database = nil, collection = nil)
        @__database = database
        @__collection = collection
        self
      end
    end
  end
end
