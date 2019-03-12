module RRRSpec

  RSpec.describe Registry do
    subject { Registry }

    it 'should return a runner on .rb' do
      expect(subject.get_runner_factory('.rb')).to be_truthy
    end

    it 'should raise exception on .feature' do
      expect { subject.get_runner_factory('.feature') }.to raise_error('There is no factory for .feature')
    end
  end

end
