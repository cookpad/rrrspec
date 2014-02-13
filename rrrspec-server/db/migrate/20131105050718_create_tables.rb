class CreateTables < ActiveRecord::Migration
  def change
    create_table(:tasksets) do |t|
      t.string :key
      t.string :rsync_name
      t.text :setup_command
      t.text :slave_command
      t.string :worker_type
      t.integer :max_workers
      t.integer :max_trials
      t.string :taskset_class
      t.integer :unknown_spec_timeout_sec
      t.integer :least_timeout_sec
      t.datetime :created_at

      t.string :status
      t.datetime :finished_at
      t.text :log
    end
    add_index :tasksets, :key
    add_index :tasksets, :rsync_name
    add_index :tasksets, :taskset_class
    add_index :tasksets, :created_at
    add_index :tasksets, :status

    create_table(:tasks) do |t|
      t.string :key
      t.references :taskset
      t.string :status
      t.integer :estimate_sec
      t.string :spec_file
    end
    add_index :tasks, :key
    add_index :tasks, :taskset_id
    add_index :tasks, :status

    create_table(:trials) do |t|
      t.string :key
      t.references :task
      t.references :slave
      t.datetime :started_at
      t.datetime :finished_at
      t.string :status
      t.text :stdout
      t.text :stderr
      t.integer :passed
      t.integer :pending
      t.integer :failed
    end
    add_index :trials, :key
    add_index :trials, :task_id
    add_index :trials, :slave_id

    create_table(:worker_logs) do |t|
      t.string :key
      t.string :worker_key
      t.references :taskset
      t.datetime :started_at
      t.datetime :rsync_finished_at
      t.datetime :setup_finished_at
      t.datetime :finished_at
      t.text :log
    end
    add_index :worker_logs, :key
    add_index :worker_logs, :worker_key
    add_index :worker_logs, :taskset_id

    create_table(:slaves) do |t|
      t.string :key
      t.references :taskset
      t.string :status
      t.text :log
    end
    add_index :slaves, :key
    add_index :slaves, :taskset_id
  end
end
