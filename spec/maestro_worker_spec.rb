require 'spec_helper'

describe Maestro::MaestroWorker do

  describe "Messaging" do
    before :each do
      @worker = Maestro::MaestroWorker.new
      @worker.workitem = {'fields' => {}}
      @worker.should_receive(:send_workitem_message).at_least(:once)
    end
  
    it "should send a write_output message" do
      @worker.write_output("Some Silly String")
    
      @worker.workitem["__output__"].should eql("Some Silly String")
    end
    
    it "should send a not needed message" do
      @worker.not_needed
      @worker.workitem["__not_needed__"].should be_nil
    end
  
    it "should send a cancel message" do
      @worker.cancel
      @worker.workitem["__cancel__"].should be_nil
    end
  
    it "should send a set_waiting message" do
      @worker.set_waiting(true)
      @worker.workitem["__waiting__"].should be_true
      
      @worker.set_waiting(false)
      @worker.workitem["__waiting__"].should be_nil
    end
  
    it "should send a create record message" do
      @worker.create_record_with_fields("cars", ["manu","date","name"], ["ferrari","1964","250 GTO"])
      
      @worker.workitem["__model__"].should eql("cars")
      @worker.workitem["__record_fields__"].should eql("manu,date,name")      
      @worker.workitem["__record_values__"].should eql("ferrari,1964,250 GTO")
    end
  
    it "should send a create record message with a hash" do
      fields = {"manu"=>"ferrari","date"=>"1964","name"=>"GTO"}
      @worker.create_record_with_fields("cars", fields)
      @worker.workitem["__model__"].should eql("cars")
      @worker.workitem["__record_fields__"].should eql(fields)
    end

    it "should send an update record-field message" do
      @worker.update_fields_in_record("animal", "donkey", "name", "e-or")
      
      @worker.workitem["__model__"].should eql("animal")
      @worker.workitem["__record_id__"].should eql("donkey")      
      @worker.workitem["__record_field__"].should eql("name")      
      @worker.workitem["__record_value__"].should eql("e-or")                
    end
  
    it "should send a delete record message" do
      @worker.delete_record("animal", 1)
      @worker.workitem["__model__"].should eql("animal")
      @worker.workitem["__name__"].should eql("1")
      @worker.workitem["__filter__"].should be_nil
    end

    it "should send a delete record message with a filter" do
      filter = {"type" => 1}
      @worker.delete_record("animal", filter)
      @worker.workitem["__model__"].should eql("animal")
      @worker.workitem["__filter__"].should eql(filter)
      @worker.workitem["__name__"].should be_nil
    end
  end  
  
  describe "Field handling" do
    before :each do
      @worker = Maestro::MaestroWorker.new
      @worker.workitem = {'fields' => {}}
    end

    it "should set and get errors" do
      @worker.workitem["__error__"].should be_nil
      @worker.error?.should be_false
      @worker.set_error "myerror"
      @worker.error?.should be_true
      @worker.workitem["fields"]["__error__"].should eq("myerror")
    end

    it "should set fields" do
      @worker.workitem = {'fields' => {'a' => "a"}}
      @worker.fields["a"].should eq("a")
      @worker.fields["b"] = "b"
      @worker.fields["b"].should eq("b")
    end
  end
end
