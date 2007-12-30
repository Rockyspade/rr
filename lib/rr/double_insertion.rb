module RR
  # RR::DoubleInsertion is the binding of an object and a method.
  # A double_insertion has 0 to many Double objects. Each Double
  # has Argument Expectations and Times called Expectations.
  class DoubleInsertion
    MethodArguments = Struct.new(:arguments, :block)
    attr_reader :space, :object, :method_name, :scenarios

    def initialize(space, object, method_name)
      @space = space
      @object = object
      @method_name = method_name.to_sym
      if object_has_method?(method_name)
        meta.send(:alias_method, original_method_name, method_name)
      end
      @scenarios = []
    end

    # RR::DoubleInsertion#register_scenario adds the passed in Double
    # into this DoubleInsertion's list of Double objects.
    def register_scenario(scenario)
      @scenarios << scenario
    end

    # RR::DoubleInsertion#bind injects a method that acts as a dispatcher
    # that dispatches to the matching Double when the method
    # is called.
    def bind
      define_implementation_placeholder
      returns_method = <<-METHOD
        def #{@method_name}(*args, &block)
          arguments = MethodArguments.new(args, block)
          #{placeholder_name}(arguments)
        end
      METHOD
      meta.class_eval(returns_method, __FILE__, __LINE__ - 5)
    end

    # RR::DoubleInsertion#verify verifies each Double
    # TimesCalledExpectation are met.
    def verify
      @scenarios.each do |scenario|
        scenario.verify
      end
    end

    # RR::DoubleInsertion#reset removes the injected dispatcher method.
    # It binds the original method implementation on the object
    # if one exists.
    def reset
      meta.send(:remove_method, placeholder_name)
      if object_has_original_method?
        meta.send(:alias_method, @method_name, original_method_name)
        meta.send(:remove_method, original_method_name)
      else
        meta.send(:remove_method, @method_name)
      end
    end

    def call_original_method(*args, &block)
      @object.__send__(original_method_name, *args, &block)
    end

    def object_has_original_method?
      object_has_method?(original_method_name)
    end

    protected
    def define_implementation_placeholder
      me = self
      meta.send(:define_method, placeholder_name) do |arguments|
        me.send(:call_method, arguments.arguments, arguments.block)
      end
    end

    def call_method(args, block)
      if scenario = find_scenario_to_attempt(args)
        return scenario.call(self, *args, &block)
      end
      scenario_not_found_error(*args)
    end

    def find_scenario_to_attempt(args)
      matches = DoubleMatches.new(@scenarios).find_all_matches!(args)

      unless matches.exact_terminal_scenarios_to_attempt.empty?
        return matches.exact_terminal_scenarios_to_attempt.first
      end

      unless matches.exact_non_terminal_scenarios_to_attempt.empty?
        return matches.exact_non_terminal_scenarios_to_attempt.last
      end

      unless matches.wildcard_terminal_scenarios_to_attempt.empty?
        return matches.wildcard_terminal_scenarios_to_attempt.first
      end

      unless matches.wildcard_non_terminal_scenarios_to_attempt.empty?
        return matches.wildcard_non_terminal_scenarios_to_attempt.last
      end

      unless matches.matching_scenarios.empty?
        # This will raise a TimesCalledError
        return matches.matching_scenarios.first
      end

      return nil
    end

    def scenario_not_found_error(*args)
      message = "Unexpected method invocation #{Double.formatted_name(@method_name, args)}, expected\n"
      message << Double.list_message_part(@scenarios)
      raise Errors::DoubleNotFoundError, message
    end

    def placeholder_name
      "__rr__#{@method_name}"
    end

    def original_method_name
      "__rr__original_#{@method_name}"
    end

    def object_has_method?(method_name)
      @object.methods.include?(method_name.to_s) || @object.respond_to?(method_name)
    end

    def meta
      (class << @object; self; end)
    end
  end
end