# frozen_string_literal: true

require_relative "container"

module Tabasco
  class Section < Container
    def self.container_test_id(test_id)
      @test_id = test_id.to_s.tr("_", "-")
    end

    def self.test_id
      @test_id
    end

    def container
      unless self.class.test_id
        raise "Container not configured. Define a container with `container_test_id <test_id>` in #{self.class}."
      end

      @container ||= Capybara.current_session.find("[data-testid='#{self.class.test_id}']")
    end
  end

  class Container
    def self.section(name, klass = nil, test_id: nil, &block)
      test_id = prepare_test_id(test_id || name)

      define_inline_section(name, klass, inline_superclass: Section) do
        class_eval(&block) if block

        container_test_id(test_id)
      end
    end
  end
end
