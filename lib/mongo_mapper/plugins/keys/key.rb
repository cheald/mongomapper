# encoding: UTF-8
module MongoMapper
  module Plugins
    module Keys
      class Key
        attr_accessor :name, :type, :options, :default, :ivar, :abbr

        ID_STR = '_id'

        def initialize(*args)
          options_from_args = args.extract_options!
          @name, @type = args.shift.to_s, args.shift
          validate_key_name!

          self.options = (options_from_args || {}).symbolize_keys
          @ivar = :"@#{name}"  # Optimization - used to avoid spamming #intern from internal_write_keys
          @embeddable = nil
          if abbr = @options[:abbr] || @options[:alias] || @options[:field_name]
            @abbr = abbr.to_s
          end

          # We'll use this to reduce the number of operations #get has to perform, which improves load speeds
          @is_id = @name == ID_STR
          @typecast = @options[:typecast]

          if options.key?(:default)
            self.default = self.options[:default]
          end
        end

        def persisted_name
          @abbr || @name
        end

        def ==(other)
          @name == other.name && @type == other.type && @abbr == other.abbr
        end

        def embeddable?
          # This is ugly, but it's fast. We can't use ||= because false is an expected and common value.
          return @embeddable if @embeddable != nil
          @embeddable = begin
            if type.respond_to?(:embeddable?)
              type.embeddable?
            else
              false
            end
          end
        end

        def number?
          type == Integer || type == Float
        end

        def default?
          options.key?(:default)
        end

        def get(value)
          # Special Case: Generate default _id on access
          value = default_value if @is_id and !value

          if @typecast
            klass = typecast_class  # Don't make this lookup on every call
            type.from_mongo(value).map! { |v| klass.from_mongo(v) }
          else
            type.from_mongo(value)
          end
        end

        def set(value)
          # Avoid tap here so we don't have to create a block binding.
          values = type.to_mongo(value)
          values.map! { |v| typecast_class.to_mongo(v) } if @typecast
          values
        end

        def default_value
          return unless default?
          if default.instance_of? Proc
            type.to_mongo default.call
          else
            # Using Marshal is easiest way to get a copy of mutable objects
            # without getting an error on immutable objects
            type.to_mongo Marshal.load(Marshal.dump(default))
          end
        end

        private
          def typecast_class
            @typecast_class ||= options[:typecast].constantize
          end

          def validate_key_name!
            if %w( id ).include? @name
              raise MongoMapper::InvalidKey.new("`#{@name}` is a reserved key name (did you mean to use _id?)")
            elsif !@name.match(/\A[a-z0-9_]+\z/i)
              raise MongoMapper::InvalidKey.new("`#{@name}` is not a valid key name. Keys must match [a-zA-Z0-9_]+")
            end
          end
      end
    end
  end
end
