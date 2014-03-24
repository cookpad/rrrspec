module RRRSpec
  module Web
    module OjFormatter
      def self.call(object, env)
        Oj.dump(object, mode: :compat, time_format: :ruby)
      end
    end

    class API < Grape::API
      version 'v2', using: :path
      format :json
      formatter :json, OjFormatter

      # For Index

      get '/tasksets/actives' do
        RRRSpec::Server::Taskset.using.map(&:as_json_for_index)
      end

      get '/tasksets/recents' do
        paginate(RRRSpec::Server::Taskset.recent).map(&:as_json_for_index)
      end

      # For Result Page

      params { requires :taskset_id, type: Integer }
      get '/tasksets/:taskset_id' do
        RRRSpec::Server::Taskset.includes(tasks: :trials).find(params[:taskset_id]).as_json_for_result_page
      end

      params { requires :taskset_id, type: Integer }
      get '/tasksets/:taskset_id/log' do
        { 'log' => RRRSpec::Server::Taskset.find(params[:taskset_id]).log.to_s }
      end

      params { requires :task_id, type: Integer }
      get '/tasks/:task_id/trials' do
        RRRSpec::Server::Task.find(params[:task_id]).trials.map(&:as_json_for_result_page)
      end

      params { requires :trial_id, type: Integer }
      get '/trials/:trial_id/outputs' do
        trial = RRRSpec::Server::Trial.find(params[:trial_id])
        { 'stdout' => trial.stdout.to_s, 'stderr' => trial.stderr.to_s }
      end

      params { requires :taskset_id, type: Integer }
      get '/tasksets/:taskset_id/worker_logs' do
        RRRSpec::Server::WorkerLog.where(taskset_id: params[:taskset_id]).map(&:as_json_for_result_page)
      end

      params { requires :taskset_id, type: Integer }
      get '/tasksets/:taskset_id/slaves' do
        RRRSpec::Server::Slave.includes(:trials).where(taskset_id: params[:taskset_id]).map(&:as_json_for_result_page)
      end
    end
  end
end
