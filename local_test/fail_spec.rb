describe 'test2' do
  it 'will be failed' do
    fail
  end

  it 'will be succeeded' do
    1.should == 1
  end

  it 'will be pending' do
    pending
  end
end
