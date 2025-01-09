# frozen_string_literal: true

require "capybara/dsl"
require "capybara/rspec/matchers"

require_relative "tabasco/version"

module Tabasco
  class Error < StandardError; end
end

require_relative "tabasco/page"