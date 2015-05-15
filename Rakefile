desc 'Release all gems'
task :release do
  %w[rrrspec-client rrrspec-server rrrspec-web rrrspec].each do |rrrspec_gem|
    sh "cd #{rrrspec_gem} && bundle exec rake release"
  end
end
