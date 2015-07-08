require 'spec_helper'

module RRRSpec
  module Server
    RSpec.describe Arbiter do
      before do
        RRRSpec.configuration = Configuration.new
        RRRSpec.configuration.redis = @redis
      end

      let(:taskset) do
        Taskset.create(
          'testuser', 'echo 1', 'echo 2', 'default', 'default', 3, 3, 5, 5
        )
      end

      let(:task1) do
        Task.create(taskset, 10, 'spec/test_spec.rb')
      end

      before do
        ActiveTaskset.add(taskset)
      end

      describe '.cancel' do
        context 'with the taskset running' do
          before { taskset.update_status('running') }

          it 'cancels the taskset' do
            Arbiter.cancel(taskset)
            expect(taskset.status).to eq('cancelled')
            expect(taskset).to be_queue_empty
            expect(taskset.finished_at).not_to be_nil
            expect(ActiveTaskset.list).not_to include(taskset)
            expect(PersisterQueue).not_to be_empty
          end
        end

        context 'with the taskset failed' do
          before { taskset.update_status('failed') }

          it 'does nothing' do
            Arbiter.cancel(taskset)
            expect(taskset.status).not_to eq('cancelled')
            expect(ActiveTaskset.list).not_to include(taskset)
            expect(PersisterQueue).not_to be_empty
          end
        end
      end

      describe '.check' do
        before do
          taskset.add_task(task1)
          taskset.enqueue_task(task1)
        end

        context 'when the taskset is succeeded or failed or cancelled' do
          before { taskset.update_status('failed') }
          it 'does nothing' do
            Arbiter.check(taskset)
            expect(ActiveTaskset.list).not_to include(taskset)
            expect(PersisterQueue).not_to be_empty
          end
        end

        context 'with the taskset running' do
          before { taskset.update_status('running') }

          context 'with tasks_left having item' do
            it 'calls check_task' do
              expect(Arbiter).to receive(:check_task)
              Arbiter.check(taskset)
            end
          end

          context 'with tasks_left non-empty after check_task' do
            context 'with the queue empty' do
              before do
                taskset.dequeue_task(0)
              end
              it 'calls requeue_speculative' do
                expect(Arbiter).to receive(:requeue_speculative)
                Arbiter.check(taskset)
              end
            end

            context 'with the queue non-empty' do
              it 'does nothing' do
                Arbiter.check(taskset)
                expect(taskset.status).to eq('running')
                expect(taskset.finished_at).to be_blank
                expect(ActiveTaskset.list).to include(taskset)
                expect(PersisterQueue).to be_empty
              end
            end
          end

          context 'with tasks_left empty after check_task' do
            before { taskset.finish_task(task1) }

            context 'with all tasks succeeded' do
              before { taskset.incr_succeeded_count }

              it 'marks the taskset as succeeded' do
                Arbiter.check(taskset)
                expect(taskset.status).to eq("succeeded")
                expect(taskset.finished_at).not_to be_blank
                expect(ActiveTaskset.list).not_to include(taskset)
                expect(PersisterQueue).not_to be_empty
              end
            end

            context 'with some tasks failed' do
              before { taskset.incr_failed_count }

              it 'marks the taskset as failed' do
                Arbiter.check(taskset)
                expect(taskset.status).to eq("failed")
                expect(taskset.finished_at).not_to be_nil
                expect(ActiveTaskset.list).not_to include(taskset)
                expect(PersisterQueue).not_to be_empty
              end
            end
          end
        end
      end

      describe '.check_task' do
        before do
          taskset.add_task(task1)
          taskset.enqueue_task(task1)
        end

        let(:logger) { TimedLogger.new(taskset) }
        let(:slave) { Slave.create }

        context 'with some trials running' do
          let(:trial1) { Trial.create(task1, slave) }

          before do
            trial1.start
          end

          context 'with the slave alive' do
            before { slave.heartbeat(30) }

            it 'does nothing' do
              Arbiter.check_task(logger, taskset, task1)
              expect(trial1.status).to be_blank
            end
          end

          context 'with the slave failed' do
            it 'marks error' do
              Arbiter.check_task(logger, taskset, task1)
              expect(trial1.status).to eq('error')
            end
          end
        end

        context 'with a trial passed' do
          let(:trial1) { Trial.create(task1, slave) }
          let(:trial2) { Trial.create(task1, slave) }

          before do
            trial1.start
            trial1.finish('passed', '', '', nil, nil, nil)
            trial2.start
            trial2.finish('error', '', '', nil, nil, nil)
          end

          it 'sets status passed' do
            Arbiter.check_task(logger, taskset, task1)
            expect(task1.status).to eq('passed')
            expect(taskset.tasks_left).not_to include(task1)
            expect(taskset.succeeded_count).to eq(1)
            expect(taskset.failed_count).to eq(0)
          end
        end

        context 'with a trial pending' do
          let(:trial1) { Trial.create(task1, slave) }
          let(:trial2) { Trial.create(task1, slave) }

          before do
            trial1.start
            trial1.finish('pending', '', '', nil, nil, nil)
            trial2.start
            trial2.finish('error', '', '', nil, nil, nil)
          end

          it 'sets status pending' do
            Arbiter.check_task(logger, taskset, task1)
            expect(task1.status).to eq('pending')
            expect(taskset.tasks_left).not_to include(task1)
            expect(taskset.succeeded_count).to eq(1)
            expect(taskset.failed_count).to eq(0)
          end
        end

        context 'with the task fully tried' do
          let(:trial1) { Trial.create(task1, slave) }
          let(:trial2) { Trial.create(task1, slave) }
          let(:trial3) { Trial.create(task1, slave) }

          before do
            trial1.start
            trial1.finish('error', '', '', nil, nil, nil)
            trial2.start
            trial2.finish('error', '', '', nil, nil, nil)
            trial3.start
            trial3.finish('error', '', '', nil, nil, nil)
          end

          it 'marks failed' do
            Arbiter.check_task(logger, taskset, task1)
            expect(task1.status).to eq('failed')
            expect(taskset.tasks_left).not_to include(task1)
            expect(taskset.succeeded_count).to eq(0)
            expect(taskset.failed_count).to eq(1)
          end
        end

        context 'when re-triable' do
          let(:trial1) { Trial.create(task1, slave) }
          let(:trial2) { Trial.create(task1, slave) }

          before do
            trial1.start
            trial1.finish('error', '', '', nil, nil, nil)
            trial2.start
            trial2.finish('error', '', '', nil, nil, nil)
          end

          it 'does nothing' do
            Arbiter.check_task(logger, taskset, task1)
            expect(task1.status).to be_blank
            expect(taskset.tasks_left).to include(task1)
            expect(taskset.succeeded_count).to eq(0)
            expect(taskset.failed_count).to eq(0)
          end
        end
      end

      describe '.requeue_speculative' do
        let(:logger) { TimedLogger.new(taskset) }
        let(:slave) { Slave.create }

        let(:task2) do
          Task.create(taskset, 10, 'spec/test_spec2.rb')
        end

        before do
          taskset.add_task(task1)
          taskset.add_task(task2)
        end

        context 'with some no-running-trial tasks' do
          let(:trial1_1) { Trial.create(task1, slave) }

          before do
            trial1_1.start
          end

          it 'enqueues one no-running-trial task' do
            Arbiter.requeue_speculative(logger, taskset, [task1, task2])
            expect(taskset).not_to be_queue_empty
            expect(taskset.dequeue_task(0)).to eq(task2)
          end
        end

        context 'with all tasks running' do
          let(:trial1_1) { Trial.create(task1, slave) }
          let(:trial1_2) { Trial.create(task2, slave) }
          let(:trial2_2) { Trial.create(task2, slave) }

          before do
            trial1_1.start
            trial1_2.start
            trial2_2.start
          end

          it 'enqueues one least tried task' do
            Arbiter.requeue_speculative(logger, taskset, [task1, task2])
            expect(taskset).not_to be_queue_empty
            expect(taskset.dequeue_task(0)).to eq(task1)
          end
        end
      end

      describe '.fail' do
        context 'with the taskset running' do
          before { taskset.update_status('running') }

          it 'fails the taskset' do
            Arbiter.fail(taskset)
            expect(taskset.status).to eq('failed')
            expect(taskset).to be_queue_empty
            expect(taskset.finished_at).not_to be_nil
            expect(ActiveTaskset.list).not_to include(taskset)
            expect(PersisterQueue).not_to be_empty
          end
        end

        context 'with the taskset cancelled' do
          before { taskset.update_status('cancelled') }

          it 'does nothing' do
            Arbiter.fail(taskset)
            expect(taskset.status).not_to eq('failed')
            expect(ActiveTaskset.list).not_to include(taskset)
            expect(PersisterQueue).not_to be_empty
          end
        end
      end

      describe '.trial' do
        before do
          taskset.add_task(task1)
          taskset.enqueue_task(task1)
        end

        before do
          taskset.dequeue_task(0)
        end

        let(:slave) { Slave.create }
        let(:trial) { Trial.create(task1, slave) }

        context 'when the task is already finished' do
          before { task1.update_status('passed') }

          it 'does nothing' do
            Arbiter.trial(trial)
            expect(trial.status).to be_nil
            expect(task1.status).to eq('passed')
          end
        end

        context 'with the trial not-running' do
          context 'with maximally retried' do
            let(:trial2) { Trial.create(task1, slave) }
            let(:trial3) { Trial.create(task1, slave) }

            before do
              trial2.finish('error', '', '', nil, nil, nil)
              trial3.finish('error', '', '', nil, nil, nil)
            end

            it 'finishes the trial and marks the task failed' do
              Arbiter.trial(trial)
              expect(trial.status).to eq('error')
              expect(task1.status).to eq('failed')
              expect(taskset.tasks_left).not_to include(task1)
              expect(taskset).to be_queue_empty
              expect(taskset.succeeded_count).to eq(0)
              expect(taskset.failed_count).to eq(1)
            end
          end

          context 'when re-triable' do
            it 'finishes the trial and requeues the task' do
              Arbiter.trial(trial)
              expect(trial.status).to eq('error')
              expect(task1.status).to be_nil
              expect(taskset.tasks_left).to include(task1)
              expect(taskset.dequeue_task(0)).to eq(task1)
              expect(taskset.succeeded_count).to eq(0)
              expect(taskset.failed_count).to eq(0)
            end
          end
        end

        context 'with the trial passed' do
          before do
            trial.finish('passed', '', '', nil, nil, nil)
          end

          it 'marks the task as passed' do
            Arbiter.trial(trial)
            expect(task1.status).to eq('passed')
            expect(taskset.tasks_left).not_to include(task1)
            expect(taskset).to be_queue_empty
            expect(taskset.succeeded_count).to eq(1)
            expect(taskset.failed_count).to eq(0)
          end
        end

        context 'with the trial pending' do
          before { trial.finish('pending', '', '', 0, 1, 0) }

          it 'marks the task as pending' do
            Arbiter.trial(trial)
            expect(task1.status).to eq('pending')
            expect(taskset.tasks_left).not_to include(task1)
            expect(taskset).to be_queue_empty
            expect(taskset.succeeded_count).to eq(1)
            expect(taskset.failed_count).to eq(0)
          end
        end

        context 'with the trial failed' do
          before { trial.finish('failed', '', '', 0, 0, 1) }

          context 'with another trial running' do
            let(:trial2) { Trial.create(task1, slave) }

            before { trial2 }

            context 'maximally retried' do
              let(:trial3) { Trial.create(task1, slave) }
              let(:trial4) { Trial.create(task1, slave) }

              before do
                trial3
                trial4
              end

              context 'enough to judge failed' do
                before do
                  trial3.finish('error', '', '', nil, nil, nil)
                  trial4.finish('error', '', '', nil, nil, nil)
                end

                it 'finishes the trial and marks the task failed' do
                  Arbiter.trial(trial)
                  expect(trial.status).to eq('failed')
                  expect(task1.status).to eq('failed')
                  expect(taskset.tasks_left).not_to include(task1)
                  expect(taskset).to be_queue_empty
                  expect(taskset.succeeded_count).to eq(0)
                  expect(taskset.failed_count).to eq(1)
                end
              end

              context 'not-enough to judge failed' do
                it 'does nothing' do
                  Arbiter.trial(trial)
                  expect(task1.status).to be_blank
                  expect(taskset.tasks_left).to include(task1)
                  expect(taskset).to be_queue_empty
                  expect(taskset.succeeded_count).to eq(0)
                  expect(taskset.failed_count).to eq(0)
                end
              end
            end

            context 'retriable' do
              before do
                trial2.finish('error', '', '', nil, nil, nil)
              end

              it 'requeue the task' do
                Arbiter.trial(trial)
                expect(task1.status).to be_nil
                expect(taskset.tasks_left).to include(task1)
                expect(taskset.dequeue_task(0)).to eq(task1)
                expect(taskset.succeeded_count).to eq(0)
                expect(taskset.failed_count).to eq(0)
              end
            end
          end

          context 'maximally retried' do
            let(:trial2) { Trial.create(task1, slave) }
            let(:trial3) { Trial.create(task1, slave) }

            before do
              trial2.finish('error', '', '', nil, nil, nil)
              trial3.finish('error', '', '', nil, nil, nil)
            end

            it 'marks the task as failed' do
              Arbiter.trial(trial)
              expect(task1.status).to eq('failed')
              expect(taskset.tasks_left).not_to include(task1)
              expect(taskset).to be_queue_empty
              expect(taskset.succeeded_count).to eq(0)
              expect(taskset.failed_count).to eq(1)
            end
          end

          context 'when re-triable' do
            it 'requeue the task' do
              Arbiter.trial(trial)
              expect(task1.status).to be_nil
              expect(taskset.tasks_left).to include(task1)
              expect(taskset.dequeue_task(0)).to eq(task1)
              expect(taskset.succeeded_count).to eq(0)
              expect(taskset.failed_count).to eq(0)
            end
          end
        end
      end
    end
  end
end
