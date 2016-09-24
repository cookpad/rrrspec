require 'spec_helper'
require 'rrrspec/client/rspec_runner'

module RRRSpec
  module Client
    RSpec.describe RSpecRunner do
      describe '#setup' do
        before do
          RRRSpec.configuration = Configuration.new
        end

        let(:runner) { described_class.new }

        it 'should be able to setup' do
          status, _outbuf, _errbuf = runner.setup(__FILE__)
          expect(status).to be_truthy
        end
      end
    end
  end
end
