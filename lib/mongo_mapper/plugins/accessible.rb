module MongoMapper
  module Plugins
    module Accessible
      extend ActiveSupport::Concern
      include ::ActiveModel::MassAssignmentSecurity

      module ClassMethods
        def accessible_attributes?
          _accessible_attributes?
        end
      end

      def attributes=(attributes={}, options = {})
        role = options[:as] || :default
        attributes = sanitize_for_mass_assignment(attributes, role) unless options[:without_protection]
        super sanitize_for_mass_assignment(attributes)
      end

      def accessible_attributes(*args)
        self.class.accessible_attributes(*args)
      end

      def accessible_attributes?
        self.class.accessible_attributes?
      end
    end
  end
end
