module RRRSpec
  module Server
    MasterConfig = Struct.new(
      :redis,
      :execute_log_text_path,
      :json_cache_path,
    )

    WorkerConfig = Struct.new(
      :master_url,
      :rsync_remote_path,
      :rsync_options,
      :working_dir,
      :worker_type,
      :slave_processes,
    )
  end
end
