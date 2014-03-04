class TimestampAndRename < ActiveRecord::Migration
  def change
    change_table(:slaves) do |t|
      t.rename :key, :name
      t.timestamps
    end

    change_table(:tasks) do |t|
      t.integer :hard_timeout_sec
      t.integer :soft_timeout_sec
      t.timestamps
    end

    change_table(:tasksets) do |t|
      t.datetime :updated_at
      t.remove :unknown_spec_timeout_sec
      t.remove :least_timeout_sec
    end

    change_table(:trials) do |t|
      t.timestamps
    end

    change_table(:worker_logs) do |t|
      t.rename :worker_key, :worker_name
      t.timestamps
    end
  end
end
