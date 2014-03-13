class Rpc < ActiveRecord::Migration
  def change
    change_table(:tasks) do |t|
      t.string :spec_sha1
      t.index :spec_sha1
      t.remove :key
      t.remove :estimate_sec
      t.rename :spec_file, :spec_path
    end

    change_table(:tasksets) do |t|
      t.remove :key
    end

    change_table(:trials) do |t|
      t.remove :key
      t.index :status
    end

    change_table(:worker_logs) do |t|
      t.remove :key
      t.rename :finished_at, :rspec_finished_at
    end
  end
end
