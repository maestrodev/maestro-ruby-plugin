require 'spec_helper'

describe Maestro::MaestroWorker do

  let(:workitem) {{'fields' => {}}}
  before { subject.workitem = workitem }

  describe 'Mock' do
    before { Maestro::MaestroWorker.mock! }
    after { Maestro::MaestroWorker.unmock! }

    it 'should mock send_workitem_message calls' do
      subject.should_not_receive(:ruote_participant)
      subject.write_output('Some test string')
    end
    context 'when accessing output' do
      before { subject.write_output("xxx") }
      its(:output) { should eq("xxx") }
    end
  end

  describe 'Messaging' do
    let(:ruote_participants) { double("ruote_participants") }

    before :each do
      ruote_participants.should_receive(:send_workitem_message).at_least(:once).with(workitem)
      subject.stub(:ruote_participants => ruote_participants)
      subject.should_receive(:send_workitem_message).at_least(:once).and_call_original
    end

    context 'when sending a write_output message' do
      before { subject.write_output('Some Silly String') }
      it { subject.workitem['__output__'].should eql('Some Silly String') }
      it { subject.workitem['__streaming__'].should be_nil }
      it("output should not be accesible without mock!") { expect(subject.output).to be_nil }
    end

    it 'should aggregate output' do
      subject.write_output('Some Silly String')
      subject.workitem['__output__'].should eql('Some Silly String')
      subject.workitem['__streaming__'].should be_nil

      subject.write_output("1", :buffer => true)
      subject.workitem['__output__'].should eql('Some Silly String')
      subject.workitem['__streaming__'].should be_nil
      subject.write_output("22", :buffer => true)
      subject.workitem['__output__'].should eql('Some Silly String')
      subject.workitem['__streaming__'].should be_nil

      # Should auto-send after 2 second delay
      sleep 3
      subject.write_output("333", :buffer => true)
      subject.workitem['__output__'].should eql('122333')
      subject.workitem['__streaming__'].should be_nil
      subject.write_output("4444", :buffer => true)
      subject.workitem['__output__'].should eql('122333')
      subject.workitem['__streaming__'].should be_nil

      # When called without aggregate, should purge
      subject.write_output("5555")
      subject.workitem['__output__'].should eql('44445555')
      subject.workitem['__streaming__'].should be_nil
    end

    it 'should send a not needed message' do
      subject.not_needed
      subject.workitem['__not_needed__'].should be_nil
    end

    it 'should send a cancel message' do
      subject.cancel
      subject.workitem['__cancel__'].should be_nil
    end

    it 'should send a set_waiting message' do
      # expects already in before :each block, so putting it here too causes test fail
#      ruote_participants.should_receive(:send_workitem_message).with(@workitem)
      subject.set_waiting(true)
      subject.workitem['__waiting__'].should be_true

      subject.set_waiting(false)
      subject.workitem['__waiting__'].should be_nil
    end

    it 'should send a create record message' do
      subject.create_record_with_fields('cars', ['manu', 'date', 'name'], ['ferrari', '1964', '250 GTO'])

      subject.workitem['__model__'].should eql('cars')
      subject.workitem['__record_fields__'].should eql('manu,date,name')
      subject.workitem['__record_values__'].should eql('ferrari,1964,250 GTO')
    end

    it 'should send a create record message with a hash' do
      fields = {'manu' => 'ferrari', 'date' => '1964', 'name' => 'GTO'}
      subject.create_record_with_fields('cars', fields)
      subject.workitem['__model__'].should eql('cars')
      subject.workitem['__record_fields__'].should eql(fields)
    end

    it 'should send an update record-field message' do
      subject.update_fields_in_record('animal', 'donkey', 'name', 'e-or')

      subject.workitem['__model__'].should eql('animal')
      subject.workitem['__record_id__'].should eql('donkey')
      subject.workitem['__record_field__'].should eql('name')
      subject.workitem['__record_value__'].should eql('e-or')
    end

    it 'should send a delete record message' do
      subject.delete_record('animal', 1)
      subject.workitem['__model__'].should eql('animal')
      subject.workitem['__name__'].should eql('1')
      subject.workitem['__filter__'].should be_nil
    end

    it 'should send a delete record message with a filter' do
      filter = {'type' => 1}
      subject.delete_record('animal', filter)
      subject.workitem['__model__'].should eql('animal')
      subject.workitem['__filter__'].should eql(filter)
      subject.workitem['__name__'].should be_nil
    end
  end

  describe 'Field handling' do
    let(:workitem) {{'fields' => {'a' => 'a'}}}

    it 'should set and get errors' do
      subject.workitem['__error__'].should be_nil
      subject.error?.should be_false
      subject.set_error 'myerror'
      subject.error?.should be_true
      subject.workitem['fields']['__error__'].should eq('myerror')
    end

    it 'should set fields' do
      subject.fields['a'].should eq('a')
      subject.fields['b'] = 'b'
      subject.fields['b'].should eq('b')
    end
    it { should have_field('a', 'a') }
    it { should_not have_field('b') }
  end

  describe 'Helpers' do
    it 'should validate JSON data contained in strings' do
      subject.is_json?('{"key": "a string"}').should be_true
      subject.is_json?('a string').should be_false
    end
  end

  describe 'Errors' do
    class ErrorTestWorker < Maestro::MaestroWorker
      def configerror_test
        raise MaestroDev::Plugin::ConfigError, 'Bad Config - what are you feeding me?'
      end

      def pluginerror_test
        raise MaestroDev::Plugin::PluginError, 'PluginError - I had a problem'
      end

      def error_test
        raise Exception, 'noooo'
      end
    end

    subject { ErrorTestWorker.new }

    it 'should handle a ConfigError for bad config' do
      subject.perform(:configerror_test, workitem)
      workitem['fields']['__error__'].should include('Bad Config')
      workitem['__output__'].should be_nil
    end

    it 'should handle a PluginError' do
      subject.perform(:pluginerror_test, workitem)
      workitem['fields']['__error__'].should include('PluginError - I had a problem')
      workitem['__output__'].should be_nil
    end

    it 'should handle an unexpected Error' do
      subject.perform(:error_test, workitem)
      workitem['fields']['__error__'].should include('Unexpected error executing task: Exception noooo')
      workitem['__output__'].should be_nil
    end
  end
end
