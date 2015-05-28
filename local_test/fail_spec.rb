describe 'test2' do
  it 'will be failed' do
    fail
  end

  it 'will be succeeded' do
    expect(1).to eq(1)
  end

  it 'will be pending' do
    pending
    expect(1).to eq(2)
  end

  it 'will be skipped' do
    skip
  end
end
