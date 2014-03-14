module RRRSpec
  module Server
    MasterConfig = Struct.new(
      :port,
      :redis,
      :execute_log_text_path,
      :json_cache_path,
      :daemonize,
      :pidfile,
      :monitor,
    )

    WorkerConfig = Struct.new(
      :master_url,
      :rsync_remote_path,
      :rsync_options,
      :working_dir,
      :worker_type,
      :slave_processes,
      :daemonize,
      :pidfile,
      :monitor,
    )
  end
end
