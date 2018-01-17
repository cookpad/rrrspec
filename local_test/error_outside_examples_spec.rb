describe 'test4' do
  describe 'outside error' do
    include_context 'not exist context'
    it 'cause outside error' do
      expect(1).to eq(1)
    end
  end
end
