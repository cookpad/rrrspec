# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140304025444) do

  create_table "slaves", force: true do |t|
    t.string   "name"
    t.integer  "taskset_id"
    t.string   "status"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "slaves", ["name"], name: "index_slaves_on_name"
  add_index "slaves", ["taskset_id"], name: "index_slaves_on_taskset_id"

  create_table "tasks", force: true do |t|
    t.string   "key"
    t.integer  "taskset_id"
    t.string   "status"
    t.integer  "estimate_sec"
    t.string   "spec_file"
    t.integer  "hard_timeout_sec"
    t.integer  "soft_timeout_sec"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "tasks", ["key"], name: "index_tasks_on_key"
  add_index "tasks", ["status"], name: "index_tasks_on_status"
  add_index "tasks", ["taskset_id"], name: "index_tasks_on_taskset_id"

  create_table "tasksets", force: true do |t|
    t.string   "key"
    t.string   "rsync_name"
    t.text     "setup_command", limit: 4294967295
    t.text     "slave_command", limit: 4294967295
    t.string   "worker_type"
    t.integer  "max_workers"
    t.integer  "max_trials"
    t.string   "taskset_class"
    t.datetime "created_at"
    t.string   "status"
    t.datetime "finished_at"
    t.datetime "updated_at"
  end

  add_index "tasksets", ["created_at"], name: "index_tasksets_on_created_at"
  add_index "tasksets", ["key"], name: "index_tasksets_on_key"
  add_index "tasksets", ["rsync_name"], name: "index_tasksets_on_rsync_name"
  add_index "tasksets", ["status"], name: "index_tasksets_on_status"
  add_index "tasksets", ["taskset_class"], name: "index_tasksets_on_taskset_class"

  create_table "trials", force: true do |t|
    t.string   "key"
    t.integer  "task_id"
    t.integer  "slave_id"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string   "status"
    t.integer  "passed"
    t.integer  "pending"
    t.integer  "failed"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "trials", ["key"], name: "index_trials_on_key"
  add_index "trials", ["slave_id"], name: "index_trials_on_slave_id"
  add_index "trials", ["task_id"], name: "index_trials_on_task_id"

  create_table "worker_logs", force: true do |t|
    t.string   "key"
    t.string   "worker_name"
    t.integer  "taskset_id"
    t.datetime "started_at"
    t.datetime "rsync_finished_at"
    t.datetime "setup_finished_at"
    t.datetime "finished_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "worker_logs", ["key"], name: "index_worker_logs_on_key"
  add_index "worker_logs", ["taskset_id"], name: "index_worker_logs_on_taskset_id"
  add_index "worker_logs", ["worker_name"], name: "index_worker_logs_on_worker_name"

end
