module RRRSpec
  def self.finished_fullset
    worker = Worker.create('default')
    taskset = Taskset.create(
      'testuser', 'echo 1', 'echo 2', 'default', 'default', 3, 3, 5, 5
    )
    task = Task.create(taskset, 10, 'spec/test_spec.rb')
    taskset.add_task(task)
    taskset.enqueue_task(task)
    ActiveTaskset.add(taskset)
    worker_log = WorkerLog.create(worker, taskset)
    worker_log.set_rsync_finished_time
    worker_log.append_log('worker_log log body')
    worker_log.set_setup_finished_time
    slave = Slave.create
    taskset.add_slave(slave)
    slave.append_log('slave log body')
    trial = Trial.create(task, slave)
    trial.start
    trial.finish('pending', 'stdout body', 'stderr body', 10, 2, 0)
    task.update_status('pending')
    taskset.incr_succeeded_count
    taskset.finish_task(task)
    taskset.update_status('succeeded')
    taskset.set_finished_time
    ActiveTaskset.remove(taskset)
    slave.update_status('normal_exit')
    worker_log.set_finished_time

    return worker, taskset, task, worker_log, slave, trial
  end
end
