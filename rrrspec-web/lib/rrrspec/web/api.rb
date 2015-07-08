require 'grape'
require 'api-pagination'
require 'oj'

module RRRSpec
  module Web
    DEFAULT_PER_PAGE = 10

    module OjFormatter
      def self.call(object, env)
        Oj.dump(object, mode: :compat, time_format: :ruby)
      end
    end

    class APIv2 < Grape::API
      version 'v2', using: :path
      format :json
      formatter :json, OjFormatter
      set :per_page, DEFAULT_PER_PAGE

      rescue_from(ActiveRecord::RecordNotFound) do
        [404, {}, ['']]
      end

      # For Index

      get '/tasksets/actives' do
        ActiveTaskset.list.map do |taskset|
          {
            key: taskset.key,
            status: taskset.status,
            rsync_name: taskset.rsync_name,
            created_at: taskset.created_at.iso8601,
          }
        end
      end

      get '/tasksets/recents' do
        paginate(RRRSpec::Server::Persistence::Taskset.recent).map(&:as_json_for_index)
      end

      # For Result Page

      # Notice that this method takes taskset key.
      params { requires :taskset_key, type: String }
      get '/tasksets/:taskset_key' do
        RRRSpec::Server::Persistence::Taskset.includes(tasks: :trials).where(key: params[:taskset_key]).first!.as_json_for_result_page
      end

      params { requires :taskset_id, type: Integer }
      get '/tasksets/:taskset_id/log' do
        { 'log' => RRRSpec::Server::Persistence::Taskset.find(params[:taskset_id]).log.to_s }
      end

      params { requires :task_id, type: Integer }
      get '/tasks/:task_id/trials' do
        RRRSpec::Server::Persistence::Task.find(params[:task_id]).trials.map(&:as_json_for_result_page)
      end

      params { requires :trial_id, type: Integer }
      get '/trials/:trial_id/outputs' do
        trial = RRRSpec::Server::Persistence::Trial.find(params[:trial_id])
        { 'stdout' => trial.stdout.to_s, 'stderr' => trial.stderr.to_s }
      end

      params { requires :taskset_id, type: Integer }
      get '/tasksets/:taskset_id/worker_logs' do
        RRRSpec::Server::Persistence::Taskset.find(params[:taskset_id]).worker_logs.map(&:as_json_for_result_page)
      end

      params { requires :taskset_id, type: Integer }
      get '/tasksets/:taskset_id/slaves' do
        RRRSpec::Server::Persistence::Taskset.includes(slaves: :trials).find(params[:taskset_id]).slaves.map(&:as_json_for_result_page)
      end
    end
  end
end
