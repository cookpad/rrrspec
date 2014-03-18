module RRRSpec
  module Client
    ClientConfig = Struct.new(
      :master_url,

      :packaging_dir,
      :rsync_remote_path,
      :rsync_options,
      :unknown_spec_timeout_sec,
      :least_timeout_sec,
      :average_multiplier,
      :hard_timeout_margin_sec,

      :rsync_name,
      :setup_command,
      :slave_command,
      :worker_type,
      :taskset_class,
      :max_workers,
      :max_trials,
      :spec_files,
    )
  end
end
