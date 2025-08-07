# frozen_string_literal: true
require 'rails/generators/base'

module Graphql
  module Generators
    module RelationshipExtractor
      def relationships
        klass&.reflect_on_all_associations(:has_many)&.map { |rel| generate_relationship_string(rel) }  || []
      end

      def generate_relationsip_string(relationship)
        name = relationship.name.to_s
        type = relationship.options[:class_name]
        "#{name}:#{type}"
      end

      def klass
        @klass ||= Module.const_get(name.camelize)
      rescue NameError
        @klass = nil
      end
    end
  end
end
