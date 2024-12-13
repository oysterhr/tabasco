# frozen_string_literal: true

require_relative "section"

module Oyster
  module Harbor
    class Page < Section
      def self.url(static_path = nil, &block)
        # rubocop: disable ThreadSafety/InstanceVariableInClassMethod
        @url_value = static_path || block
        # rubocop: enable ThreadSafety/InstanceVariableInClassMethod
      end

      def self.url_value
        # rubocop: disable ThreadSafety/InstanceVariableInClassMethod
        @url_value
        # rubocop: enable ThreadSafety/InstanceVariableInClassMethod
      end

      def self.visit(...)
        new(...).tap do |instance|
          instance.send(:_capybara).visit(instance.path)

          instance.ensure_loaded
        end
      end

      def path
        @path ||= begin
          url_value = self.class.url_value

          unless url_value
            raise "URL not configured. Define a path with `url { ... }` or `url '/static/path'` in #{self.class}."
          end

          url_value.is_a?(Proc) ? instance_eval(&url_value) : url_value
        end
      end
    end
  end
end
