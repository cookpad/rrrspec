RRRSpec.configure do |conf|
  conf.redis = {
    host: ENV['REDIS_HOST'],
  }
end

RRRSpec.configure(:worker) do |conf|
  RRRSpec.logger = Logger.new($stderr)
  conf.rsync_remote_path = "#{ENV['MASTER_HOST']}:/tmp/rrrspec-rsync"
  conf.rsync_options = %w(
    --compress
    --times
    --recursive
    --links
    --perms
    --inplace
    --delete
  ).join(' ')
  conf.worker_type = 'default'
  conf.working_dir = '/tmp/working'
  conf.slave_processes = 8
  conf.stdout_path = '/dev/stdout'
  conf.stderr_path = '/dev/stderr'
end
