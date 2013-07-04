# encoding: UTF-8
module MongoMapper
  module Plugins
    module Scopes
      extend ActiveSupport::Concern

      included do
        class_attribute :_scopes
      end

      module ClassMethods
        def scope(name, scope = method(name))
          if MongoMapper.rails4?
            ActiveSupport::Deprecation.warn(
              "Using #scope without passing a callable object is deprecated. For " \
              "example `scope :red, where(color: 'red')` should be changed to " \
              "`scope :red, -> { where(color: 'red') }`. (If you prefer, you can " \
              "just define a class method named `self.red`.)"
            ) unless scope.nil? or scope.respond_to?(:call)
          end

          # Assign to _scopes instead of using []= to avoid mixing subclass scopes
          scope_proc = lambda do |*args|
            result = scope.respond_to?(:call) ? scope.call(*args) : scope
            result = self.query(result) if result.is_a?(Hash)
            self.query.merge(result)
          end
          self._scopes = scopes.merge(name => scope_proc)
          singleton_class.send :define_method, name, &scope_proc
        end

        def scopes
          self._scopes ||= {}
        end
      end
    end
  end
end
