# frozen_string_literal: true

require "active_support/core_ext/class/attribute"
require "capybara/dsl"
require "capybara/rspec/matchers"

require_relative "tabasco/version"

module Tabasco
  class Error < StandardError; end
  class PreconditionNotMetError < Error; end

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

require_relative "tabasco/configuration"
require_relative "tabasco/page"
