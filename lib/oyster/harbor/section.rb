# frozen_string_literal: true

module Oyster
  module Harbor
    PreconditionNotMetError = Class.new(StandardError)
    class CapybaraAPI
      include Capybara::DSL
    end

    class Section
      include Capybara::RSpecMatchers

      private_class_method :new # Use .load instead (or .visit for Page objects)

      def self.load(...)
        new(...).tap(&:ensure_loaded)
      end

      def self.attribute(attr_name)
        attributes << attr_name.to_sym
        attr_reader attributes.last
      end

      # rubocop: disable ThreadSafety/InstanceVariableInClassMethod
      def self.attributes
        @attributes ||= []
      end

      def self.container_test_id(test_id)
        @test_id = test_id.to_s.tr("_", "-")
      end

      def self.test_id
        @test_id
      end

      def self.ensure_loaded(&block)
        @ensure_loaded_block = block
      end

      def self.ensure_loaded_block
        @ensure_loaded_block
      end
      # rubocop: enable ThreadSafety/InstanceVariableInClassMethod

      def self.section(name, klass = nil, test_id: nil, &block)
        test_id = (test_id || name).to_s.tr("_", "-")

        parent_name = self.name
        section_name = name.to_s.capitalize
        parent_attributes = attributes

        klass ||= Class.new(Section) do
          container_test_id(test_id)

          parent_attributes.each do |attr_name|
            attribute attr_name
          end

          def self.attribute(*)
            raise ArgumentError, "Attributes cannot be defined in anonymous sections. " \
              "They inherit all arguments from parent pages/sections automatically."
          end

          # Simple and naive implementation for Anonymous classes
          # Will raise a Capybara error if the container cannot be found
          # Can be overriden in the inline block anyway
          ensure_loaded { container }

          # rubocop: disable Style/DocumentDynamicEvalDefinition
          class_eval <<~METHOD, __FILE__, __LINE__ + 1
            class << self
              def name
                "#{parent_name}|#{section_name}"
              end

              def inspect
                "Section(\#{name})"
              end

              alias_method :to_s, :inspect
            end

            def inspect
              "#<\#{self.class.inspect}:\#{object_id}>"
            end

            alias_method :to_s, :inspect
          METHOD
          # rubocop: ename Style/DocumentDynamicEvalDefinition

          class_eval(&block) if block
        end

        define_method(name) do |&block|
          instance = instance_variable_get(:"@#{name}")
          unless instance
            inherited_attributes = self.class.attributes.each_with_object({}) do |attr_name, hash|
              hash[attr_name] = public_send(attr_name)
            end

            # Filter attributes to only include those defined in the explicit class
            filtered_attributes = inherited_attributes.slice(*klass.attributes)

            instance = klass.load(**filtered_attributes)
            instance_variable_set(:"@#{name}", instance)
          end

          block&.call(instance)
          instance
        end
      end

      # Automatically adds a private precondition method for any has_X? query method added.
      # If a method named `has_<something>?` is defined, we will create a corresponding
      # `has_<something>!` method.
      #
      # The `has_X!` method will call the original `has_X?` method and raise a `PreconditionNotMetError`
      # if the result is not truthy.
      def self.method_added(method_name)
        method_name = method_name.to_s

        return unless method_name.start_with?("has_") && method_name.end_with?("?")

        bang_method_name = method_name.to_s.sub("?", "!")

        return if instance_methods.include?(bang_method_name.to_sym)

        original_method = instance_method(method_name)

        define_method(bang_method_name) do |*args, **kwargs, &block|
          result = original_method.bind_call(self, *args, **kwargs, &block)

          return result if result

          raise(
            PreconditionNotMetError,
            "#{bang_method_name}: Expected #{method_name} to return truthy, but it returned #{result.inspect}",
          )
        end

        # We don't want to expose the bang method to the outside world
        private bang_method_name
      end

      def initialize(**kwargs)
        self.class.attributes.each do |attr_name|
          instance_variable_set(:"@#{attr_name}", kwargs[attr_name])
        end

        # raise an error if any of the attributes are not defined in the constructor
        unknown_attributes = kwargs.keys - self.class.attributes
        unless unknown_attributes.empty?
          raise ArgumentError, "Unknown attribute(s) passed to #{self.class}: #{unknown_attributes}"
        end

        # raise an error if any of the attributes are not defined in the constructor
        missing_attributes = self.class.attributes - kwargs.keys
        unless missing_attributes.empty?
          raise ArgumentError, "Missing attribute(s) passed to #{self.class}: #{missing_attributes}"
        end
      end

      def _capybara
        # We just use this as a way to call capybara DSL methods directly
        # Subclasses should not use this though
        @_capybara ||= CapybaraAPI.new
      end

      # Instance method to call the stored block
      def ensure_loaded
        unless self.class.ensure_loaded_block
          raise "Subclasses of Oyster::Harbor::Section must define how to check whether your " \
                "content has loaded with the ensure_loaded { ... } DSL method."

        end

        instance_exec(&self.class.ensure_loaded_block)
      end

      def container
        unless self.class.test_id
          raise "Container not configured. Define a container with `container_test_id <test_id>` in #{self.class}."
        end

        @container ||= _capybara.find("[data-testid='#{self.class.test_id}']")
      end

      # Allows this page object to be used as subject of `expect` blocks:
      # expect(page_object_instance).to have_content
      #
      # And narrows any node dom finding operations to the container wrapper
      (Capybara::Session::NODE_METHODS + [:within]).each do |method|
        class_eval <<~METHOD, __FILE__, __LINE__ + 1
          def #{method}(...)                           # def find(...)
            wrapping { _capybara.#{method}(...) }      #  wrapping { _capybara.find(...) }
          end                                          # end
        METHOD
      end

      # Allows section objects to be used as arguments of Capybara::Session#within
      alias_method :to_capybara_node, :container

      private

      def wrapping
        return yield if already_wrapped?

        result = nil
        _capybara.within(container) { result = yield }

        result
      end

      def already_wrapped?
        own_wrapper_path = container.path

        _capybara.page.send(:scopes).any? { |el| el&.path&.start_with?(own_wrapper_path) }
      end
    end
  end
end
