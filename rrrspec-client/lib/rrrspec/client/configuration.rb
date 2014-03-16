module RRRSpec
  module Client
    ClientConfig = Struct.new(
      :master_url,
      :packaging_dir,
      :rsync_name,
      :rsync_remote_path,
      :rsync_options,
      :spec_files,
      :setup_command,
      :slave_command,
      :taskset_class,
      :worker_type,
      :max_workers,
      :max_trials,
      :unknown_spec_timeout_sec,
      :least_timeout_sec,
    )
  end
end
