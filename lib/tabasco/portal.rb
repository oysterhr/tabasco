# frozen_string_literal: true

require_relative "container"

module Tabasco
  class Portal < Container
    class MissingHandleError < Error; end

    def self.handle(value = nil)
      return @handle if value.nil?

      @handle = value.to_sym
    end

    def initialize(...)
      raise MissingHandleError, "A handle must be defined when using portals" if self.class.handle.nil?

      super
    end

    private

    def container
      @container ||= case Tabasco.configuration.portal(self.class.handle)
      in { test_id: test_id }
        Capybara.current_session.find("[data-testid='#{self.class.prepare_test_id(test_id)}']")
      else
        raise ArgumentError, "The portal #{self.class.handle.inspect} is not configured"
      end
    end
  end

  class Container
    def self.portal(name, klass = nil, &block)
      define_inline_section(name, klass, inline_superclass: Portal) do
        handle name
        class_eval(&block) if block
      end
    end
  end
end
