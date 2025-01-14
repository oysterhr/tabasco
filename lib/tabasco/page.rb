# frozen_string_literal: true

require_relative "section"

module Tabasco
  class Page < Section
    def self.url(static_path = nil, &block)
      @url_value = static_path || block
    end

    def self.url_value
      @url_value
    end

    def container
      return super if self.class.test_id

      Capybara.current_session.find("body")
    end

    def self.visit(...)
      new(...).tap do |instance|
        Capybara.current_session.visit(instance.path)

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
