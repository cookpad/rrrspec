require 'spec_helper'

module RRRSpec
  module Server
    describe MasterAPIHandler do
      let(:max_workers) { 10 }
      let(:max_trials) { 3 }
      let(:hard_timeout_sec1) { 60 }
      let(:hard_timeout_sec2) { 2*60 }
      let(:soft_timeout_sec1) { 30 }
      let(:soft_timeout_sec2) { 2*30 }
      let(:tasks) do
        [
          ['test_spec_path1', 'test_spec_sha1', hard_timeout_sec1, soft_timeout_sec1],
          ['test_spec_path2', 'test_spec_sha2', hard_timeout_sec2, soft_timeout_sec2],
        ]
      end

      before do
        RRRSpec.application_type = :master
        RRRSpec.config = MasterConfig.new
        RRRSpec.config.execute_log_text_path = Dir.mktmpdir
        RRRSpec.config.json_cache_path = Dir.mktmpdir
      end

      after do
        FileUtils.remove_entry_secure(RRRSpec.config.execute_log_text_path)
        FileUtils.remove_entry_secure(RRRSpec.config.json_cache_path)
      end

      def call_create_taskset
        master_transport.sync_call(:create_taskset,
                                   'test_rsync_name', 'test_setup_command', 'test_slave_command',
                                   'test_worker_type', 'test_taskset_class',
                                   max_workers, max_trials, tasks)
      end

      def taskset; Taskset.first; end
      let(:taskset_ref) { taskset.to_ref }
      def task; Task.first end
      let(:task_ref) { task.to_ref }
      def slave; Slave.first; end
      let(:slave_ref) { slave.to_ref }
      def trial; Trial.first; end
      let(:trial_ref) { trial.to_ref }

      describe MasterAPIHandler::TasksetQuery do
        describe '#create_taskset' do
          it 'creates a taskset' do
            taskset_ref = call_create_taskset
            taskset = Taskset.from_ref(taskset_ref)
            expect(taskset.rsync_name).to eq('test_rsync_name')
            expect(taskset.tasks.pluck(:spec_path)).to match_array([
              'test_spec_path1', 'test_spec_path2',
            ])
          end

          it 'enqueue the tasks ordered by the timeout sec' do
            taskset_ref = call_create_taskset
            taskset = Taskset.from_ref(taskset_ref)

            expect(taskset.queue.size).to eq(2)
            expect(taskset.queue.dequeue.spec_path).to eq('test_spec_path2')
            expect(taskset.queue.dequeue.spec_path).to eq('test_spec_path1')
            expect(taskset.queue.dequeue).to be_nil
          end
        end

        describe '#dequeue_task' do
          before { call_create_taskset }

          it 'dequeues a task' do
            task_ref, spec_path, hard_timeout_sec, soft_timeout_sec = master_transport.sync_call(:dequeue_task, taskset_ref)
            expect(spec_path).to eq('test_spec_path2')
            expect(hard_timeout_sec).to eq(hard_timeout_sec2)
            expect(soft_timeout_sec).to eq(soft_timeout_sec2)
            expect(taskset.queue.size).to eq(1)
          end

          context 'with all tasks finished' do
            before do
              taskset.tasks.each do |task|
                task.update_attributes(status: 'passed')
              end
              taskset.queue.clear
            end

            it 'returns nil' do
              expect(master_transport.sync_call(:dequeue_task, taskset_ref)).to be_nil
            end

            it 'finishes the taskset' do
              master_transport.sync_call(:dequeue_task, taskset_ref)
              expect(taskset.status).to eq('succeeded')
            end
          end

          context 'with some tasks left' do
            before do
              taskset.queue.clear
            end

            it 'enqueues a task and return one' do
              expect(master_transport.sync_call(:dequeue_task, taskset_ref)).not_to be_nil
            end
          end
        end

        describe '#fail_taskset' do
          before { call_create_taskset }
          before { taskset.update_attributes(status: 'running') }

          it 'fails the taskset' do
            master_transport.sync_call(:fail_taskset, taskset_ref)
            expect(taskset.status).to eq('failed')
            expect(taskset.queue.empty?).to be_true
          end

          it 'does not overwrite the status' do
            taskset.update_attributes(status: 'cancelled')
            master_transport.sync_call(:fail_taskset, taskset_ref)
            expect(taskset.status).to eq('cancelled')
          end
        end

        describe '#cancel_taskset' do
          before { call_create_taskset }
          before { taskset.update_attributes(status: 'running') }

          it 'cancels the taskset' do
            master_transport.sync_call(:cancel_taskset, taskset_ref)
            expect(taskset.status).to eq('cancelled')
            expect(taskset.queue.empty?).to be_true
          end

          it 'does not overwrite the status' do
            taskset.update_attributes(status: 'failed')
            master_transport.sync_call(:cancel_taskset, taskset_ref)
            expect(taskset.status).to eq('failed')
          end
        end
      end

      describe MasterAPIHandler::TaskQuery do
        before { call_create_taskset }

        describe '#reversed_enqueue_task' do
          let(:task) { taskset.tasks.first }
          let(:task_ref) { task.to_ref }

          it 'enqueues in the first' do
            master_transport.sync_call(:reversed_enqueue_task, task_ref)
            expect(taskset.queue.size).to eq(3)
            expect(taskset.queue.dequeue.spec_path).to eq(task.spec_path)
          end
        end
      end

      describe MasterAPIHandler::TrialQuery do
        before { call_create_taskset }
        before { Slave.create(name: 'test_slave_name', taskset_id: taskset.id) }

        describe '#create_trial' do
          it 'creates a trial' do
            trial_ref = master_transport.sync_call(:create_trial, task_ref, slave_ref)
            trial = Trial.from_ref(trial_ref)
            expect(trial.task).to eq(task)
            expect(trial.slave).to eq(slave)
          end
        end

        describe '#start_trial' do
          let(:trial_ref) { master_transport.sync_call(:create_trial, task_ref, slave_ref) }

          it 'starts a trial' do
            master_transport.sync_call(:start_trial, trial_ref)
            expect(trial.started_at).not_to be_nil
          end
        end

        describe '#finish_trial' do
          let(:trial_ref) { master_transport.sync_call(:create_trial, task_ref, slave_ref) }
          before { master_transport.sync_call(:start_trial, trial_ref) }

          it 'finishes a trial' do
            master_transport.sync_call(:finish_trial, trial_ref, 'pending', 'test_stdout', 'test_stderr', 3, 4, 0)
            expect(trial.finished_at).not_to be_nil
            expect(trial.status).to eq('pending')
            expect(trial.stdout.to_s).to eq('test_stdout')
            expect(trial.passed).to eq(3)
          end

          it 'finishes the task' do
            master_transport.sync_call(:finish_trial, trial_ref, 'pending', 'test_stdout', 'test_stderr', 3, 4, 0)
            expect(task.status).to eq('pending')
          end
        end
      end

      describe MasterAPIHandler::WorkerQuery do
        before { call_create_taskset }

        describe '#current_taskset' do
        end
      end

      describe MasterAPIHandler::WorkerLogQuery do
        before { call_create_taskset }

        describe '#create_worker_log' do
        end

        describe '#append_worker_log_log' do
        end

        describe '#set_rsync_finished_time' do
        end

        describe '#set_setup_finished_time' do
        end

        describe '#set_rspec_finished_time' do
        end
      end

      describe MasterAPIHandler::SlaveQuery do
        before { call_create_taskset }

        describe '#create_slave' do
        end

        describe '#current_trial' do
        end

        describe '#finish_slave' do
        end

        describe '#force_finish_slave' do
        end
      end
    end
  end
end
