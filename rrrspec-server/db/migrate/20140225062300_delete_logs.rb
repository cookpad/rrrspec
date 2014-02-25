class DeleteLogs < ActiveRecord::Migration
  def change
    change_table :slaves do |t|
      t.remove :log
    end

    change_table :tasksets do |t|
      t.remove :log
    end

    change_table :trials do |t|
      t.remove :stdout, :stderr
    end

    change_table :worker_logs do |t|
      t.remove :log
    end
  end
end
