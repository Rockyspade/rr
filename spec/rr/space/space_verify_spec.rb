require "spec/spec_helper"

module RR
  describe Space, "#verify_ordered_scenario", :shared => true do
    before do
      @space = Space.new
      @object = Object.new
      @method_name = :foobar
      @double_insertion = @space.double_insertion(@object, @method_name)
    end

    it "raises an error when Double is NonTerminal" do
      scenario = @space.scenario(@double_insertion)
      @space.register_ordered_scenario(scenario)

      scenario.any_number_of_times
      scenario.should_not be_terminal

      proc do
        @space.verify_ordered_scenario(scenario)
      end.should raise_error(
      Errors::DoubleOrderError,
      "Ordered Doubles cannot have a NonTerminal TimesCalledExpectation"
      )
    end
  end

  describe Space do
    it_should_behave_like "RR::Space"

    describe "#verify_double_insertions" do
      before do
        @space = Space.new
        @object1 = Object.new
        @object2 = Object.new
        @method_name = :foobar
      end

      it "verifies and deletes the double_insertions" do
        double1 = @space.double_insertion(@object1, @method_name)
        double1_verify_calls = 0
        double1_reset_calls = 0
        (
        class << double1;
          self;
        end).class_eval do
          define_method(:verify) do ||
            double1_verify_calls += 1
          end
          define_method(:reset) do ||
            double1_reset_calls += 1
          end
        end
        double2 = @space.double_insertion(@object2, @method_name)
        double2_verify_calls = 0
        double2_reset_calls = 0
        (
        class << double2;
          self;
        end).class_eval do
          define_method(:verify) do ||
            double2_verify_calls += 1
          end
          define_method(:reset) do ||
            double2_reset_calls += 1
          end
        end

        @space.verify_double_insertions
        double1_verify_calls.should == 1
        double2_verify_calls.should == 1
        double1_reset_calls.should == 1
        double1_reset_calls.should == 1
      end
    end

    describe "#verify_double" do
      it_should_behave_like "RR::Space"

      before do
        @space = Space.new
        @object = Object.new
        @method_name = :foobar
      end

      it "verifies and deletes the double_insertion" do
        double_insertion = @space.double_insertion(@object, @method_name)
        @space.double_insertions[@object][@method_name].should === double_insertion
        @object.methods.should include("__rr__#{@method_name}")

        verify_calls = 0
        (
        class << double_insertion;
          self;
        end).class_eval do
          define_method(:verify) do ||
            verify_calls += 1
          end
        end
        @space.verify_double(@object, @method_name)
        verify_calls.should == 1

        @space.double_insertions[@object][@method_name].should be_nil
        @object.methods.should_not include("__rr__#{@method_name}")
      end

      it "deletes the double_insertion when verifying the double_insertion raises an error" do
        double_insertion = @space.double_insertion(@object, @method_name)
        @space.double_insertions[@object][@method_name].should === double_insertion
        @object.methods.should include("__rr__#{@method_name}")

        verify_called = true
        (
        class << double_insertion;
          self;
        end).class_eval do
          define_method(:verify) do ||
            verify_called = true
            raise "An Error"
          end
        end
        proc {@space.verify_double(@object, @method_name)}.should raise_error
        verify_called.should be_true

        @space.double_insertions[@object][@method_name].should be_nil
        @object.methods.should_not include("__rr__#{@method_name}")
      end
    end

    describe "#verify_ordered_scenario where the passed in scenario is at the front of the queue" do
      it_should_behave_like "RR::Space#verify_ordered_scenario"

      it "keeps the scenario when times called is not verified" do
        scenario = @space.scenario(@double_insertion)
        @space.register_ordered_scenario(scenario)

        scenario.twice
        scenario.should be_attempt

        @space.verify_ordered_scenario(scenario)
        @space.ordered_scenarios.should include(scenario)
      end

      it "removes the scenario when times called expectation should no longer be attempted" do
        scenario = @space.scenario(@double_insertion)
        @space.register_ordered_scenario(scenario)

        scenario.with(1).once
        @object.foobar(1)
        scenario.should_not be_attempt

        @space.verify_ordered_scenario(scenario)
        @space.ordered_scenarios.should_not include(scenario)
      end
    end

    describe "#verify_ordered_scenario where the passed in scenario is not at the front of the queue" do
      it_should_behave_like "RR::Space#verify_ordered_scenario"

      it "raises error" do
        first_scenario = scenario
        second_scenario = scenario

        proc do
          @space.verify_ordered_scenario(second_scenario)
        end.should raise_error(
        Errors::DoubleOrderError,
        "foobar() called out of order in list\n" <<
        "- foobar()\n" <<
        "- foobar()"
        )
      end

      def scenario
        scenario_definition = @space.scenario(@double_insertion).once
        @space.register_ordered_scenario(scenario_definition.scenario)
        scenario_definition.scenario
      end
    end
  end
end