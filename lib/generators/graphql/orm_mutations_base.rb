# frozen_string_literal: true
require 'rails/generators'
require 'rails/generators/named_base'
require_relative 'core'

module Graphql
  module Generators
    # TODO: What other options should be supported?
    #
    # @example Generate a `GraphQL::Schema::RelayClassicMutation` by name
    #     rails g graphql:mutation CreatePostMutation
    class OrmMutationsBase < Rails::Generators::NamedBase
      include Core
      include Rails::Generators::ResourceHelpers

      desc "Create a Relay Classic mutation by name"

      class_option :orm, banner: "NAME", type: :string, required: true,
                         desc: "ORM to generate the controller for"

      class_option :namespaced_types,
        type: :boolean,
        required: false,
        default: false,
        banner: "Namespaced",
        desc: "If the generated types will be namespaced"

      def create_mutation_file
        template "mutation_#{operation_type}.erb", File.join(options[:directory], "/mutations/", class_path, "#{file_name}_#{operation_type}.rb")

        sentinel = /class .*MutationType\s*<\s*[^\s]+?\n/m
        in_root do
          path = "#{options[:directory]}/types/mutation_type.rb"
          invoke "graphql:install:mutation_root" unless File.exist?(path)
          inject_into_file "#{options[:directory]}/types/mutation_type.rb", "    field :#{file_name}_#{operation_type}, mutation: Mutations::#{class_name}#{operation_type.classify}\n", after: sentinel, verbose: false, force: false
        end
      end

      # Take a type expression in any combination of GraphQL or Ruby styles
      # and return it in a specified output style
      # TODO: nullability / list with `mode: :graphql` doesn't work
      # @param type_expresson [String]
      # @param mode [Symbol]
      # @param null [Boolean]
      # @return [(String, Boolean)] The type expression, followed by `null:` value
      def self.normalize_type_expression(type_expression, mode:, null: true)
        if type_expression.start_with?("!")
          normalize_type_expression(type_expression[1..-1], mode: mode, null: false)
        elsif type_expression.end_with?("!")
          normalize_type_expression(type_expression[0..-2], mode: mode, null: false)
        elsif type_expression.start_with?("[") && type_expression.end_with?("]")
          name, is_null = normalize_type_expression(type_expression[1..-2], mode: mode, null: null)
          ["[#{name}]", is_null]
        elsif type_expression.start_with?("Types::")
          normalize_type_expression(type_expression[7..-1], mode: mode, null: null)
        elsif type_expression.start_with?("types.")
          normalize_type_expression(type_expression[6..-1], mode: mode, null: null)
        else
          case mode
          when :ruby
            case type_expression
            when "Int"
              ["Integer", null]
            when "Integer", "Float", "Boolean", "String", "ID"
              [type_expression, null]
            else
              ["Types::#{type_expression.camelize}Type", null]
            end
          when :graphql
            [type_expression.camelize, null]
          else
            raise "Unexpected normalize mode: #{mode}"
          end
        end
      end

      private

      def type_ruby_name
        @type_ruby_name ||= self.class.normalize_type_expression(name, mode: :ruby)[0]
      end

      def ruby_class_name
        class_prefix = 
          if options[:namespaced_types]
            "#{graphql_type.pluralize.camelize}::"
          else
            ""
          end
        @ruby_class_name || class_prefix + type_ruby_name.sub(/^Types::/, "")
      end
    end
  end
end
