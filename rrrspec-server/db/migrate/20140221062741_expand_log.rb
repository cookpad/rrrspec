class ExpandLog < ActiveRecord::Migration
  def change
    change_column(:tasksets, :setup_command, :text, limit: 4294967295)
    change_column(:tasksets, :slave_command, :text, limit: 4294967295)
    change_column(:tasksets, :log, :text, limit: 4294967295)
    change_column(:trials, :stdout, :text, limit: 4294967295)
    change_column(:trials, :stderr, :text, limit: 4294967295)
    change_column(:worker_logs, :log, :text, limit: 4294967295)
    change_column(:slaves, :log, :text, limit: 4294967295)
  end
end
