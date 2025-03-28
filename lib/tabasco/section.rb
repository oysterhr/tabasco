# frozen_string_literal: true

require_relative "section/ensure_loaded"

module Tabasco
  class Section
    include Capybara::RSpecMatchers
    include EnsureLoaded

    private_class_method :new # Use .load instead (or .visit for Page objects)

    class_attribute :_attributes, :test_id
    class << self
      def load(...)
        new(...).tap(&:ensure_loaded)
      end

      def attribute(attr_name)
        attributes << attr_name.to_sym
        attr_reader attributes.last
      end

      # We use class_attribute to ensure subclasses inherit their parent's configurations.
      # However, we cannot use class_attribute's `default:` option to initialize an empty
      # array because it gets evaluated once, causing the same underlying array to be shared
      # across all classes.
      #
      # Additionally, the way class_attribute works does not allow us to override a getter
      # and call `super`.
      # Therefore, we named the class_attribute as :_attributes and explicitly defined the
      # `attributes` getter with the necessary initialization logic.
      def attributes
        self._attributes ||= []
      end

      def container_test_id(test_id)
        self.test_id = test_id.to_s.tr("_", "-")
      end

      def section(name, klass = nil, test_id: nil, &)
        define_inline_section(name, klass, test_id: test_id, &)
      end

      def portal(name, concrete_klass = nil, local_concrete_klass = nil, &)
        Tabasco.configuration.portal(name) in { klass:, test_id: }

        if klass && concrete_klass && !concrete_klass.ancestors.include?(klass)
          raise InconsistentPortalKlassError,
            "The class #{concrete_klass} provided to the portal \"#{name}\" " \
            "must inherit from the configured portal class #{klass}."
        end

        klass = concrete_klass || klass
        define_inline_section(name, klass, test_id:, portal: true, &)
      end

      private

      # rubocop: disable Metrics/MethodLength
      # rubocop: disable Metrics/PerceivedComplexity
      def define_inline_section(name, klass = nil, test_id: nil, portal: false, &block)
        test_id = (test_id || name).to_s.tr("_", "-")

        parent_attributes = attributes

        # Inherit from a concrete klass, so inline definitions can override behavior
        # without messing the actual concrete class
        klass = Class.new(klass) if klass
        klass ||= Class.new(Section) do
          parent_attributes.each do |attr_name|
            attribute attr_name
          end

          def self.attribute(*)
            raise ArgumentError, "Attributes cannot be defined in anonymous sections. " \
                                 "They inherit all arguments from parent pages/sections automatically."
          end

          # Simple and naive implementation for Anonymous classes
          # Will raise a Capybara error if the container cannot be found
          # Can be overridden in the inline block anyway
          ensure_loaded { container }
        end

        # Configurations we want to apply to both inline or concrete classes
        klass.class_eval do
          # Although concrete classes specify a container test id, we want the local context
          # to have a higher precedence.
          container_test_id(test_id)

          klass.class_eval(&block) if block
        end

        define_method(name) do |&block_argument|
          instance = instance_variable_get(:"@#{name}")
          unless instance
            inherited_attributes = self.class.attributes.each_with_object({}) do |attr_name, hash|
              hash[attr_name] = public_send(attr_name)
            end

            # Filter attributes to only include those defined in the explicit class
            filtered_attributes = inherited_attributes.slice(*klass.attributes)

            instance = klass.load(name, _parent_scope: portal ? nil : self, **filtered_attributes)
            instance_variable_set(:"@#{name}", instance)
          end

          block_argument&.call(instance)
          instance
        end
      end
      # rubocop: enable Metrics/MethodLength
      # rubocop: enable Metrics/PerceivedComplexity

      # Automatically adds a private precondition method for any has_X? query method added.
      # If a method named `has_<something>?` is defined, we will create a corresponding
      # `has_<something>!` method.
      #
      # The `has_X!` method will call the original `has_X?` method and raise a `PreconditionNotMetError`
      # if the result is not truthy.
      def method_added(method_name)
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

        super
      end
    end

    attr_reader :_handle

    def initialize(_handle = nil, _parent_scope: nil, **kwargs)
      @_handle = _handle
      @_parent_scope = _parent_scope

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
      return if missing_attributes.empty?

      raise ArgumentError, "Missing attribute(s) passed to #{self.class}: #{missing_attributes}"
    end

    def container
      unless self.class.test_id
        raise "Container not configured. Define a container with `container_test_id <test_id>` in #{self.class}."
      end

      @container ||= (@_parent_scope || Capybara.current_session).find("[data-testid='#{self.class.test_id}']")
    end

    # Allows this page object to be used as subject of `expect` blocks:
    # expect(page_object_instance).to have_content
    #
    # And narrows any node dom finding operations to the container wrapper
    (Capybara::Session::NODE_METHODS + [:within]).each do |method|
      class_eval <<~METHOD, __FILE__, __LINE__ + 1
        def #{method}(...)                                       # def find(...)
          wrapping { Capybara.current_session.#{method}(...) }   #  wrapping { Capybara.current_session.find(...) }
        end                                                      # end
      METHOD
    end

    # Allows section objects to be used as arguments of Capybara::Session#within
    # Can't use alias since we need container to resolve in subclasses (for test mostly)
    def to_capybara_node = container

    private

    def wrapping
      return yield if already_wrapped?

      result = nil
      Capybara.current_session.within(container) { result = yield }

      result
    end

    def already_wrapped?
      own_wrapper_path = container.path

      Capybara.current_session.send(:scopes).any? { |el| el&.path&.start_with?(own_wrapper_path) }
    end
  end
end
