require 'rspec/expectations'

# it { should have_field("name","value") }
# it { should_not have_field("name") }
RSpec::Matchers.define :have_field do |field_name, field_value|
  match_for_should do |actual|
    actual.get_field(field_name) and actual.get_field(field_name) == field_value
  end
  failure_message_for_should do |actual|
    value = actual.get_field(field_name) || "nil"
    "expected that #{actual} would have field #{field_name} set to #{field_value} but it is set to '#{value}'"
  end
  match_for_should_not do |actual|
    actual.get_field(field_name).nil?
  end
  failure_message_for_should_not do |actual|
    "expected that #{actual} would not have field #{field_name} but it is set to '#{actual.get_field(field_name)}'"
  end
end
