# frozen_string_literal: true

require "capybara/dsl"
require "capybara/rspec/matchers"
require_relative "tabasco/version"
require_relative "tabasco/configuration"

module Tabasco
  class Error < StandardError; end

  def self.configure
    yield configuration.dsl
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.reset_configuration!
    @configuration = nil
  end
end

require_relative "tabasco/page"
require_relative "tabasco/portal"
