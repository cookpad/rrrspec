require 'fileutils'
require 'uuidtools'

module RRRSpec
  def self.convert_if_present(h, key)
    if h[key].present?
      h[key] = yield h[key]
    else
      h[key] = nil
    end
  end

  module ArbiterQueue
    ARBITER_QUEUE_KEY = 'rrrspec:arbiter_queue'

    # Public: Cancel the taskset.
    def self.cancel(taskset)
      RRRSpec.redis.rpush(ARBITER_QUEUE_KEY, "cancel\t#{taskset.key}")
    end

    # Public: Mark taskset failed
    def self.fail(taskset)
      RRRSpec.redis.rpush(ARBITER_QUEUE_KEY, "fail\t#{taskset.key}")
    end

    # Public: Check if there is no tasks left in the taskset.
    def self.check(taskset)
      RRRSpec.redis.rpush(ARBITER_QUEUE_KEY, "check\t#{taskset.key}")
    end

    # Public: Update the status of the task based on the result of the trial.
    def self.trial(trial)
      RRRSpec.redis.rpush(ARBITER_QUEUE_KEY, "trial\t#{trial.key}")
    end

    # Public: Dequeue the task.
    #
    # Returns [command_name, arg]
    def self.dequeue
      _, line = RRRSpec.redis.blpop(ARBITER_QUEUE_KEY, 0)
      command, arg = line.split("\t", 2)
      case command
      when 'cancel', 'check', 'fail'
        arg = Taskset.new(arg)
      when 'trial'
        arg = Trial.new(arg)
      else
        raise 'Unknown command'
      end
      return command, arg
    end
  end

  module DispatcherQueue
    DISPATCHER_QUEUE_KEY = 'rrrspec:dispatcher_queue'
    DEFAULT_TIMEOUT = 10

    # Public: Check the active tasksets and dispatch them
    def self.notify
      RRRSpec.redis.rpush(DISPATCHER_QUEUE_KEY, 0)
    end

    # Public: Wait for the check command
    def self.wait(timeout=DEFAULT_TIMEOUT)
      RRRSpec.redis.blpop(DISPATCHER_QUEUE_KEY, timeout)
    end
  end

  module PersisterQueue
    PERSISTER_QUEUE_KEY = 'rrrspec:persister_queue'

    module_function

    # Public: Request the taskset to be persisted.
    def enqueue(taskset)
      RRRSpec.redis.rpush(PERSISTER_QUEUE_KEY, taskset.key)
    end

    # Public: Wait for the persistence request.
    def dequeue
      _, line = RRRSpec.redis.blpop(PERSISTER_QUEUE_KEY, 0)
      Taskset.new(line)
    end

    def empty?
      RRRSpec.redis.llen(PERSISTER_QUEUE_KEY) == 0
    end
  end

  module StatisticsUpdaterQueue
    STATISTICS_UPDATER_QUEUE_KEY = 'rrrspec:statistics_updater_queue'

    module_function

    # Public: Request the taskset to be added to statistics.
    def enqueue(taskset, recalculate = false)
      RRRSpec.redis.rpush(STATISTICS_UPDATER_QUEUE_KEY,
        {taskset: taskset.key, recalculate: recalculate}.to_json)
    end

    # Public: Wait for the update request.
    def dequeue
      _, line = RRRSpec.redis.blpop(STATISTICS_UPDATER_QUEUE_KEY, 0)
      request = JSON.parse(line)

      [Taskset.new(request['taskset']), request['recalculate']]
    end

    def empty?
      RRRSpec.redis.llen(STATISTICS_UPDATER_QUEUE_KEY) == 0
    end
  end

  module ActiveTaskset
    ACTIVE_TASKSET_KEY = 'rrrspec:active_taskset'

    # Public: Add the taskset to the active tasksets
    def self.add(taskset)
      RRRSpec.redis.rpush(ACTIVE_TASKSET_KEY, taskset.key)
    end

    # Public: Remove the taskset from the active tasksets
    def self.remove(taskset)
      RRRSpec.redis.lrem(ACTIVE_TASKSET_KEY, 0, taskset.key)
    end

    # Public: Returns an array of the active tasksets.
    def self.list
      RRRSpec.redis.lrange(ACTIVE_TASKSET_KEY, 0, -1).map do |key|
        Taskset.new(key)
      end
    end

    # Public: Returns an array of the active tasksets whose rsync name is
    # specified one.
    def self.all_tasksets_of(rsync_name)
      list.select { |taskset| taskset.rsync_name == rsync_name }
    end
  end

  class Taskset
    attr_reader :key

    def initialize(taskset_key)
      @key = taskset_key
    end

    # Public: Create a new taskset.
    # NOTE: This method will **NOT** call ActiveTaskset.add.
    def self.create(rsync_name, setup_command, slave_command, worker_type,
                    taskset_class, max_workers, max_trials,
                    unknown_spec_timeout_sec, least_timeout_sec)
      now = Time.zone.now
      # For the reasons unknown, UUIDTools::UUID.timestamp_create changes 'now'.
      taskset_key = RRRSpec.make_key(
        'rrrspec', 'taskset', UUIDTools::UUID.timestamp_create(now.dup)
      )
      RRRSpec.redis.hmset(
        taskset_key,
        'rsync_name', rsync_name,
        'setup_command', setup_command,
        'slave_command', slave_command,
        'worker_type', worker_type,
        'max_workers', max_workers,
        'max_trials', max_trials,
        'taskset_class', taskset_class,
        'unknown_spec_timeout_sec', unknown_spec_timeout_sec.to_s,
        'least_timeout_sec', least_timeout_sec.to_s,
        'created_at', now.to_s,
      )
      return new(taskset_key)
    end

    def ==(other)
      @key == other.key
    end

    def exist?
      RRRSpec.redis.exists(key)
    end

    def persisted?
      RRRSpec.redis.ttl(key) != -1
    end

    def cancel
      ArbiterQueue.cancel(self)
    end

    # ==========================================================================
    # Property

    # Public: The path name that is used in rsync
    #
    # Returns string
    def rsync_name
      RRRSpec.redis.hget(key, 'rsync_name')
    end

    # Public: The command used in setup
    #
    # Returns string
    def setup_command
      RRRSpec.redis.hget(key, 'setup_command')
    end

    # Public: The command that invokes rrrspec slave
    #
    # Returns string
    def slave_command
      RRRSpec.redis.hget(key, 'slave_command')
    end

    # Public: Type of the worker required to run the specs
    #
    # Returns string
    def worker_type
      RRRSpec.redis.hget(key, 'worker_type')
    end

    # Public: The number of workers that is used to run the specs
    #
    # Returns number
    def max_workers
      RRRSpec.redis.hget(key, 'max_workers').to_i
    end

    # Public: The number of trials that should be made.
    #
    # Returns number
    def max_trials
      RRRSpec.redis.hget(key, 'max_trials').to_i
    end

    # Public: A value that identifies the same taskset.
    #
    # Returns string
    def taskset_class
      RRRSpec.redis.hget(key, 'taskset_class')
    end

    # Public: The timeout sec for unknown spec files.
    #
    # Returns number
    def unknown_spec_timeout_sec
      RRRSpec.redis.hget(key, 'unknown_spec_timeout_sec').to_i
    end

    # Public: Timeout sec at least any specs should wait.
    #
    # Returns number
    def least_timeout_sec
      RRRSpec.redis.hget(key, 'least_timeout_sec').to_i
    end

    # Public: Returns the created_at
    #
    # Returns Time
    def created_at
      v = RRRSpec.redis.hget(key, 'created_at')
      v.present? ? Time.zone.parse(v) : nil
    end

    # ==========================================================================
    # WorkerLogs

    # Public: Add a worker log
    def add_worker_log(worker_log)
      RRRSpec.redis.rpush(RRRSpec.make_key(key, 'worker_log'),
                          worker_log.key)
    end

    # Public: Return an array of worker_logs
    def worker_logs
      RRRSpec.redis.lrange(RRRSpec.make_key(key, 'worker_log'), 0, -1).map do |key|
        WorkerLog.new(key)
      end
    end

    # ==========================================================================
    # Slaves

    # Public: Add a slave
    def add_slave(slave)
      RRRSpec.redis.rpush(RRRSpec.make_key(key, 'slave'),
                          slave.key)
    end

    # Public: Return an array of slaves
    def slaves
      RRRSpec.redis.lrange(RRRSpec.make_key(key, 'slave'), 0, -1).map do |key|
        Slave.new(key)
      end
    end

    # ==========================================================================
    # Tasks

    # Public: Add a task.
    # NOTE: This method does **NOT** enqueue to the task_queue
    def add_task(task)
      RRRSpec.redis.rpush(RRRSpec.make_key(key, 'tasks'), task.key)
      RRRSpec.redis.rpush(RRRSpec.make_key(key, 'tasks_left'), task.key)
    end

    # Public: Finish the task. It is no longer appeared in the `tasks_left`.
    def finish_task(task)
      RRRSpec.redis.lrem(RRRSpec.make_key(key, 'tasks_left'), 0, task.key)
    end

    # Public: All the tasks that are contained by the taskset.
    #
    # Returns an array of the task instances
    def tasks
      RRRSpec.redis.lrange(RRRSpec.make_key(key, 'tasks'), 0, -1).map do |key|
        Task.new(key)
      end
    end

    # Public: Size of all tasks.
    def task_size
      RRRSpec.redis.llen(RRRSpec.make_key(key, 'tasks')).to_i
    end

    # Public: All the tasks that are not migrated into the persistent store.
    # In short, the tasks that are `add_task`ed but not `finish_task`ed.
    #
    # Returns an array of the task instances.
    def tasks_left
      RRRSpec.redis.lrange(RRRSpec.make_key(key, 'tasks_left'), 0, -1).map do |key|
        Task.new(key)
      end
    end

    # Public: Enqueue the task to the task_queue.
    def enqueue_task(task)
      RRRSpec.redis.rpush(RRRSpec.make_key(key, 'task_queue'), task.key)
    end

    # Public: Enqueue the task in the reversed way.
    def reversed_enqueue_task(task)
      RRRSpec.redis.lpush(RRRSpec.make_key(key, 'task_queue'), task.key)
    end

    # Public: Dequeue the task from the task_queue.
    #
    # Returns a task or nil if timeouts
    def dequeue_task(timeout)
      if timeout < 0
        task_key = RRRSpec.redis.lpop(RRRSpec.make_key(key, 'task_queue'))
      else
        _, task_key = RRRSpec.redis.blpop(RRRSpec.make_key(key, 'task_queue'), timeout)
      end
      return nil unless task_key
      Task.new(task_key)
    end

    # Public: Remove all the tasks enqueued to the task_queue.
    def clear_queue
      RRRSpec.redis.del(RRRSpec.make_key(key, 'task_queue'))
    end

    # Public: Checks whether the task_queue is empty.
    def queue_empty?
      RRRSpec.redis.llen(RRRSpec.make_key(key, 'task_queue')) == 0
    end

    # ==========================================================================
    # Status

    # Public: Current status
    #
    # Returns either nil, "running", "succeeded", "cancelled" or "failed"
    def status
      RRRSpec.redis.hget(key, 'status')
    end

    # Public: Update the status. It should be one of:
    # ["running", "succeeded", "cancelled", "failed"]
    def update_status(status)
      RRRSpec.redis.hset(key, 'status', status)
    end

    # Public: Current succeeded task count. A task is counted as succeeded one
    # if its status is "passed" or "pending".
    #
    # Returns a number
    def succeeded_count
      RRRSpec.redis.hget(key, 'succeeded_count').to_i
    end

    # Public: Increment succeeded_count
    def incr_succeeded_count
      RRRSpec.redis.hincrby(key, 'succeeded_count', 1)
    end

    # Public: Current failed task count. A task is counted as failed one if its
    # status is "failed".
    #
    # Returns a number
    def failed_count
      RRRSpec.redis.hget(key, 'failed_count').to_i
    end

    # Public: Increment failed_count
    def incr_failed_count
      RRRSpec.redis.hincrby(key, 'failed_count', 1)
    end

    # Public: Returns the finished_at
    def finished_at
      v = RRRSpec.redis.hget(key, 'finished_at')
      v.present? ? Time.zone.parse(v) : nil
    end

    # Public: Set finished_at time if it is empty
    def set_finished_time
      RRRSpec.redis.hsetnx(key, 'finished_at', Time.zone.now.to_s)
    end

    # Public: Overall logs of the taskset
    def log
      RRRSpec.redis.get(RRRSpec.make_key(key, 'log')) || ""
    end

    # Public: Append a line to the log
    def append_log(string)
      RRRSpec.redis.append(RRRSpec.make_key(key, 'log'), string)
    end

    # ==========================================================================
    # Serialize

    def to_h
      h = RRRSpec.redis.hgetall(key)
      h['key'] = key
      h['log'] = log
      h['tasks'] = tasks.map { |task| { 'key' => task.key } }
      h['slaves'] = slaves.map { |slave| { 'key' => slave.key } }
      h['worker_logs'] = worker_logs.map { |worker_log| { 'key' => worker_log.key } }
      RRRSpec.convert_if_present(h, 'max_workers') { |v| v.to_i }
      RRRSpec.convert_if_present(h, 'max_trials') { |v| v.to_i }
      RRRSpec.convert_if_present(h, 'unknown_spec_timeout_sec') { |v| v.to_i }
      RRRSpec.convert_if_present(h, 'least_timeout_sec') { |v| v.to_i }
      RRRSpec.convert_if_present(h, 'created_at') { |v| Time.zone.parse(v) }
      RRRSpec.convert_if_present(h, 'finished_at') { |v| Time.zone.parse(v) }
      h.delete('succeeded_count')
      h.delete('failed_count')
      h
    end

    def to_json(options=nil)
      to_h.to_json(options)
    end

    # ==========================================================================
    # Persistence

    def expire(sec)
      tasks.each { |task| task.expire(sec) }
      slaves.each { |slave| slave.expire(sec) }
      worker_logs.each { |worker_log| worker_log.expire(sec) }
      RRRSpec.redis.expire(key, sec)
      RRRSpec.redis.expire(RRRSpec.make_key(key, 'log'), sec)
      RRRSpec.redis.expire(RRRSpec.make_key(key, 'slave'), sec)
      RRRSpec.redis.expire(RRRSpec.make_key(key, 'worker_log'), sec)
      RRRSpec.redis.expire(RRRSpec.make_key(key, 'task_queue'), sec)
      RRRSpec.redis.expire(RRRSpec.make_key(key, 'tasks'), sec)
      RRRSpec.redis.expire(RRRSpec.make_key(key, 'tasks_left'), sec)
    end
  end

  class WorkerLog
    attr_reader :key

    def initialize(worker_log_key)
      @key = worker_log_key
    end

    # Public: Create a new worker_log.
    # This method will call Taskset#add_worker_log
    def self.create(worker, taskset)
      worker_log_key = RRRSpec.make_key(taskset.key, worker.key)
      RRRSpec.redis.hmset(
        worker_log_key,
        'worker', worker.key,
        'taskset', taskset.key,
        'started_at', Time.zone.now.to_s,
      )
      worker_log = new(worker_log_key)
      taskset.add_worker_log(worker_log)
      return worker_log
    end

    # ==========================================================================
    # Property

    # Public: Returns the started_at
    def started_at
      v = RRRSpec.redis.hget(key, 'started_at')
      v.present? ? Time.zone.parse(v) : nil
    end

    # ==========================================================================
    # Status

    # Public: Returns the rsync_finished_at
    def rsync_finished_at
      v = RRRSpec.redis.hget(key, 'rsync_finished_at')
      v.present? ? Time.zone.parse(v) : nil
    end

    # Public: Set rsync_finished_at time
    def set_rsync_finished_time
      RRRSpec.redis.hset(key, 'rsync_finished_at', Time.zone.now.to_s)
    end

    # Public: Returns the setup_finished_at
    def setup_finished_at
      v = RRRSpec.redis.hget(key, 'setup_finished_at')
      v.present? ? Time.zone.parse(v) : nil
    end

    # Public: Set setup_finished_at time
    def set_setup_finished_time
      RRRSpec.redis.hset(key, 'setup_finished_at', Time.zone.now.to_s)
    end

    # Public: Returns the finished_at
    def finished_at
      v = RRRSpec.redis.hget(key, 'finished_at')
      v.present? ? Time.zone.parse(v) : nil
    end

    # Public: Set finished_at time if it is empty
    def set_finished_time
      RRRSpec.redis.hsetnx(key, 'finished_at', Time.zone.now.to_s)
    end

    # Public: Logs happend in worker
    def log
      RRRSpec.redis.get(RRRSpec.make_key(key, 'log')) || ""
    end

    # Public: Append a line to the log
    def append_log(string)
      RRRSpec.redis.append(RRRSpec.make_key(key, 'log'), string)
    end

    # ==========================================================================
    # Serialize

    def to_h
      h = RRRSpec.redis.hgetall(key)
      h['key'] = key
      h['log'] = log
      h['worker'] = { 'key' => h['worker'] }
      h['taskset'] = { 'key' => h['taskset'] }
      RRRSpec.convert_if_present(h, 'started_at') { |v| Time.zone.parse(v) }
      RRRSpec.convert_if_present(h, 'rsync_finished_at') { |v| Time.zone.parse(v) }
      RRRSpec.convert_if_present(h, 'setup_finished_at') { |v| Time.zone.parse(v) }
      RRRSpec.convert_if_present(h, 'finished_at') { |v| Time.zone.parse(v) }
      h
    end

    def to_json(options=nil)
      to_h.to_json(options)
    end

    # ==========================================================================
    # Persistence

    def expire(sec)
      RRRSpec.redis.expire(key, sec)
      RRRSpec.redis.expire(RRRSpec.make_key(key, 'log'), sec)
    end
  end

  class Task
    attr_reader :key

    def initialize(task_key)
      @key = task_key
    end

    def self.create(taskset, estimate_sec, spec_file)
      task_key = RRRSpec.make_key(taskset.key, 'task', spec_file)
      RRRSpec.redis.hmset(
        task_key,
        'taskset', taskset.key,
        'estimate_sec', estimate_sec,
        'spec_file', spec_file
      )
      return new(task_key)
    end

    def ==(other)
      @key == other.key
    end

    # ==========================================================================
    # Property

    # Public: Estimate time to finishe the task.
    #
    # Returns seconds or nil if there is no estimation
    def estimate_sec
      v = RRRSpec.redis.hget(key, 'estimate_sec')
      v.present? ? v.to_i : nil
    end

    # Public: Spec file to run.
    #
    # Returns a path to the spec
    def spec_file
      RRRSpec.redis.hget(key, 'spec_file')
    end

    # Public: Included taskset
    #
    # Returns a Taskset
    def taskset
      Taskset.new(RRRSpec.redis.hget(key, 'taskset'))
    end

    # ==========================================================================
    # Trial

    # Public: Returns the trials of the task.
    # The return value should be sorted in the order added.
    #
    # Returns an array of the Trials
    def trials
      RRRSpec.redis.lrange(RRRSpec.make_key(key, 'trial'), 0, -1).map do |key|
        Trial.new(key)
      end
    end

    # Public: Add a trial of the task.
    def add_trial(trial)
      RRRSpec.redis.rpush(RRRSpec.make_key(key, 'trial'),
                          trial.key)
    end

    # ==========================================================================
    # Status

    # Public: Current status
    #
    # Returns either nil, "running", "passed", "pending" or "failed"
    def status
      RRRSpec.redis.hget(key, 'status')
    end

    # Public: Update the status. It should be one of:
    # [nil, "running", "passed", "pending", "failed"]
    def update_status(status)
      if status.present?
        RRRSpec.redis.hset(key, 'status', status)
      else
        RRRSpec.redis.hdel(key, 'status')
      end
    end

    # ==========================================================================
    # Serialize

    def to_h
      h = RRRSpec.redis.hgetall(key)
      h['key'] = key
      h['trials'] = trials.map { |trial| { 'key' => trial.key } }
      h['taskset'] = { 'key' => h['taskset'] }
      RRRSpec.convert_if_present(h, 'estimate_sec') { |v| v.to_i }
      h
    end

    def to_json(options=nil)
      to_h.to_json(options)
    end

    # ==========================================================================
    # Persistence

    def expire(sec)
      trials.each { |trial| trial.expire(sec) }
      RRRSpec.redis.expire(key, sec)
      RRRSpec.redis.expire(RRRSpec.make_key(key, 'trial'), sec)
    end
  end

  class Trial
    attr_reader :key

    def initialize(trial_key)
      @key = trial_key
    end

    # Public: Create a new trial.
    # This method will call Task#add_trial and Slave#add_trial.
    def self.create(task, slave)
      trial_key = RRRSpec.make_key(
        task.key, 'trial', UUIDTools::UUID.timestamp_create
      )
      RRRSpec.redis.hmset(
        trial_key,
        'task', task.key,
        'slave', slave.key,
      )
      trial = new(trial_key)
      task.add_trial(trial)
      slave.add_trial(trial)
      return trial
    end

    # ==========================================================================
    # Property

    # Public: Tried task
    #
    # Returns a Task
    def task
      Task.new(RRRSpec.redis.hget(key, 'task'))
    end

    # Public: The slave worked for this.
    #
    # Returns a Slave
    def slave
      Slave.new(RRRSpec.redis.hget(key, 'slave'))
    end

    # ==========================================================================
    # Status

    # Public: Current status
    #
    # Returns either nil, "passed", "pending", "failed" or "error"
    def status
      RRRSpec.redis.hget(key, 'status')
    end

    # Public: Set started_at time.
    def start
      RRRSpec.redis.hset(key, 'started_at', Time.zone.now.to_s)
    end

    # Public: Finish the trial
    # status should be one of ["passed", "pending", "failed", "error"].
    # stdout and stderr should be string or nil.
    # passed, pending and failed is the count of examplegroups and should be
    # either nil or numbers.
    def finish(status, stdout, stderr, passed, pending, failed)
      RRRSpec.redis.hmset(
        key,
        'finished_at', Time.zone.now.to_s,
        'status', status,
        'stdout', stdout,
        'stderr', stderr,
        'passed', passed,
        'pending', pending,
        'failed', failed
      )
    end

    # Public: Returns the started_at
    def started_at
      v = RRRSpec.redis.hget(key, 'started_at')
      v.present? ? Time.zone.parse(v) : nil
    end

    # Public: Returns the finished_at
    def finished_at
      v = RRRSpec.redis.hget(key, 'finished_at')
      v.present? ? Time.zone.parse(v) : nil
    end

    # Public: Returns the stdout
    def stdout
      RRRSpec.redis.hget(key, 'stdout')
    end

    # Public: Returns the stderr
    def stderr
      RRRSpec.redis.hget(key, 'stderr')
    end

    # Public: Returns the passed examples
    def passed
      v = RRRSpec.redis.hget(key, 'passed')
      v.present? ? v.to_i : nil
    end

    # Public: Returns the pending examples
    def pending
      v = RRRSpec.redis.hget(key, 'pending')
      v.present? ? v.to_i : nil
    end

    # Public: Returns the failed examples
    def failed
      v = RRRSpec.redis.hget(key, 'failed')
      v.present? ? v.to_i : nil
    end

    # ==========================================================================
    # Serialize

    def to_h
      h = RRRSpec.redis.hgetall(key)
      h['key'] = key
      h['task'] = { 'key' => h['task'] }
      h['slave'] = { 'key' => h['slave'] }
      RRRSpec.convert_if_present(h, 'started_at') { |v| Time.zone.parse(v) }
      RRRSpec.convert_if_present(h, 'finished_at') { |v| Time.zone.parse(v) }
      RRRSpec.convert_if_present(h, 'passed') { |v| v.to_i }
      RRRSpec.convert_if_present(h, 'pending') { |v| v.to_i }
      RRRSpec.convert_if_present(h, 'failed') { |v| v.to_i }
      h
    end

    def to_json(options=nil)
      to_h.to_json(options)
    end

    # ==========================================================================
    # Persistence

    def expire(sec)
      RRRSpec.redis.expire(key, sec)
    end
  end

  class Worker
    attr_reader :key

    def initialize(worker_key)
      @key = worker_key
    end

    # Public: Create a new worker.
    # The worker returned is **NOT** appeared in Worker.list.
    def self.create(worker_type, hostname=RRRSpec.hostname)
      worker_key = RRRSpec.make_key('rrrspec', 'worker', hostname)
      RRRSpec.redis.hset(worker_key, 'worker_type', worker_type)

      worker = new(worker_key)
      return worker
    end

    # Public: A list of the workers which are possibly available.
    #
    # Returns an array of the workers
    def self.list
      RRRSpec.redis.smembers(RRRSpec.make_key('rrrspec', 'worker')).map do |key|
        new(key)
      end
    end

    # Public: Remove myself from the worker list.
    def evict
      RRRSpec.redis.srem(RRRSpec.make_key('rrrspec', 'worker'), key)
    end

    def ==(other)
      @key == other.key
    end

    # ==========================================================================
    # Property

    # Public: The worker_type
    def worker_type
      RRRSpec.redis.hget(key, 'worker_type')
    end

    # ==========================================================================
    # Taskset

    # Public: Current taskset
    #
    # Returns a taskset or nil
    def current_taskset
      taskset_key = RRRSpec.redis.hget(key, 'taskset')
      if taskset_key.present?
        return Taskset.new(taskset_key)
      else
        nil
      end
    end

    # Public: Update the current taskset
    def update_current_taskset(taskset)
      if taskset.present?
        RRRSpec.redis.hset(key, 'taskset', taskset.key)
      else
        RRRSpec.redis.hset(key, 'taskset', nil)
      end
    end

    # Public: Enqueue the taskset to the taskset_queue
    def enqueue_taskset(taskset)
      RRRSpec.redis.rpush(RRRSpec.make_key(key, 'worker_queue'), taskset.key)
    end

    # Public: Dequeue the taskset from the taskset_queue
    def dequeue_taskset
      _, taskset_key = RRRSpec.redis.blpop(RRRSpec.make_key(key, 'worker_queue'), 0)
      return Taskset.new(taskset_key)
    end

    # Public: Checks whether the taskset_queue is empty.
    def queue_empty?
      RRRSpec.redis.llen(RRRSpec.make_key(key, 'worker_queue')) == 0
    end

    # ==========================================================================
    # Heartbeat

    # Public: Check its existence with heartbeat key.
    #
    # Returns bool
    def exist?
      RRRSpec.redis.exists(RRRSpec.make_key(key, 'heartbeat'))
    end

    # Public: Maintain heartbeat
    def heartbeat(time)
      RRRSpec.redis.setex(RRRSpec.make_key(key, 'heartbeat'), time, "alive")
      RRRSpec.redis.sadd(RRRSpec.make_key('rrrspec', 'worker'), key)
    end
  end

  class Slave
    attr_reader :key

    def initialize(slave_key)
      @key = slave_key
    end

    def self.create
      slave_key = RRRSpec.make_key('rrrspec', 'worker', RRRSpec.hostname, 'slave', Process.getpgrp)
      slave = new(slave_key)
      return slave
    end

    def self.build_from_pid(pid)
      slave_key = RRRSpec.make_key('rrrspec', 'worker', RRRSpec.hostname, 'slave', pid)
      return new(slave_key)
    end

    # ==========================================================================
    # Status

    # Public: Returns the trials of the slave.
    # The return value should be sorted in the order added.
    #
    # Returns an array of the Trials
    def trials
      RRRSpec.redis.lrange(RRRSpec.make_key(key, 'trial'), 0, -1).map do |key|
        Trial.new(key)
      end
    end

    # Public: Add trial to the list of the trials that the slave worked for.
    def add_trial(trial)
      RRRSpec.redis.rpush(RRRSpec.make_key(key, 'trial'),
                          trial.key)
    end

    # ==========================================================================
    # Status

    # Public: Current status
    #
    # Returns either nil, "normal_exit", "timeout_exit" or "failure_exit"
    def status
      RRRSpec.redis.hget(key, 'status')
    end

    # Public: Update the status. It should be one of:
    # ["normal_exit", "timeout_exit", "failure_exit"]
    def update_status(status)
      RRRSpec.redis.hset(key, 'status', status)
    end

    # Public: Execution log of the slave
    def log
      RRRSpec.redis.get(RRRSpec.make_key(key, 'log')) || ""
    end

    # Public: Append a line to the worker_log
    def append_log(string)
      RRRSpec.redis.append(RRRSpec.make_key(key, 'log'), string)
    end

    # ==========================================================================
    # Heartbeat

    # Public: Check its existence with heartbeat key.
    #
    # Returns bool
    def exist?
      RRRSpec.redis.exists(RRRSpec.make_key(key, 'heartbeat'))
    end

    # Public: Maintain heartbeat
    def heartbeat(time)
      RRRSpec.redis.setex(RRRSpec.make_key(key, 'heartbeat'), time, "alive")
    end

    # ==========================================================================
    # Serialize

    def to_h
      h = RRRSpec.redis.hgetall(key)
      h['trials'] = trials.map { |trial| { 'key' => trial.key } }
      h['key'] = key
      h['log'] = log
      h
    end

    def to_json(options=nil)
      to_h.to_json(options)
    end

    # ==========================================================================
    # Persistence

    def expire(sec)
      RRRSpec.redis.expire(key, sec)
      RRRSpec.redis.expire(RRRSpec.make_key(key, 'trial'), sec)
      RRRSpec.redis.expire(RRRSpec.make_key(key, 'log'), sec)
      RRRSpec.redis.expire(RRRSpec.make_key(key, 'heartbeat'), sec)
    end
  end

  module TasksetEstimation
    # Public: Return the cache on the estimated execution time of the specs.
    #
    # Returns a hash of spec_file to estimate_sec
    def self.estimate_secs(taskset_class)
      h = RRRSpec.redis.hgetall(RRRSpec.make_key('rrrspec', 'estimate_sec', taskset_class))
      estimate_secs = {}
      h.each do |spec_file, estimate_sec|
        estimate_secs[spec_file] = estimate_sec.to_i
      end
      return estimate_secs
    end

    # Public: Update the estimation.
    #
    # The estimation argument should be a hash like {"spec_file" => 20}.
    def self.update_estimate_secs(taskset_class, estimation)
      return if estimation.empty?
      key = RRRSpec.make_key('rrrspec', 'estimate_sec', taskset_class)
      RRRSpec.redis.hmset(key, *estimation.to_a.flatten)
    end
  end
end
