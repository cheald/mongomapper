# encoding: UTF-8
require 'set'

module MongoMapper
  module Plugins
    module Protected
      extend ActiveSupport::Concern
      include ::ActiveModel::MassAssignmentSecurity

      module ClassMethods
        def key(*args)
          key = super
          attr_protected key.name.to_sym if key.options[:protected]
          key
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

      def attributes=(attributes={}, options = {})
        return if attributes.nil? or attributes.empty?
        @mass_assignment_options = options
        attributes = sanitize_for_mass_assignment(attributes, mass_assignment_role) unless mass_assignment_options[:without_protection]
        @mass_assignment_options = nil
        super sanitize_for_mass_assignment(attributes), options
      end

      protected

      # These exist to be overridden on models.
      def mass_assignment_options
        @mass_assignment_options ||= {}
      end

      def mass_assignment_role
        mass_assignment_options[:as] || :default
      end
    end
  end
end
