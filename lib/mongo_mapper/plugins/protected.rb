# encoding: UTF-8
begin
  require 'active_model/mass_assignment_security'
rescue LoadError; end

module MongoMapper
  module Plugins
    module Protected
      extend ActiveSupport::Concern
      # 3.x style
      if defined?(::ActiveModel::MassAssignmentSecurity)
        include ::ActiveModel::MassAssignmentSecurity

        module ClassMethods
          def key(*args)
            super.tap do |key|
              attr_protected key.name.to_sym if key.options[:protected]
            end
          end

          def accessible_attributes?
            _accessible_attributes?
          end

          def protected_attributes?
            _protected_attributes?
          end
        end

        def protected_attributes
          self.class.protected_attributes
        end

        def accessible_attributes(*args)
          self.class.accessible_attributes(*args)
        end

        def accessible_attributes?
          self.class.accessible_attributes?
        end

        def assign_attributes(attributes = {}, options = {})
          return if attributes.nil? or attributes.empty?
          @mass_assignment_options = options
          attributes = __sanitize(attributes) unless mass_assignment_options[:without_protection]
          @mass_assignment_options = nil
          super attributes, options
        end

        protected

        # These exist to be overridden on models.
        def mass_assignment_options
          @mass_assignment_options ||= {}
        end

        def mass_assignment_role
          mass_assignment_options[:as] || :default
        end

        def __sanitize(attributes)
          @sanitize_arity ||= method(:sanitize_for_mass_assignment).arity
          # Rails 3.0.x
          if @sanitize_arity == 1
            sanitize_for_mass_assignment(attributes)
          # Rails 3.1.x+_
          else
            sanitize_for_mass_assignment(attributes, mass_assignment_role)
          end
        end
      else
        # 4.0-style. Including the protected_attributes gem will restore 3.x-style functionality.
        module ClassMethods
          def attr_protected(*args)
            raise "`attr_protected` is extracted out of Rails into a gem. " \
              "Please use new recommended protection model for params" \
              "(strong_parameters) or add `protected_attributes` to your " \
              "Gemfile to use old one."
          end

          def attr_accessible(*args)
            raise "`attr_accessible` is extracted out of Rails into a gem. " \
            "Please use new recommended protection model for params" \
            "(strong_parameters) or add `protected_attributes` to your " \
            "Gemfile to use old one."
          end
        end
      end
    end
  end
end
