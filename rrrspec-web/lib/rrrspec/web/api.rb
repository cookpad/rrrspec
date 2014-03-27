require 'grape'
require 'api-pagination'
require 'oj'

module RRRSpec
  module Web
    class API < Grape::API
      version 'v1', using: :path
      format :json

      resource :tasksets do
        desc "Return active tasksets"
        get :actives do
          ActiveTaskset.list
        end

        desc "Return recently finished tasksets"
        get :recents do
          paginate(RRRSpec::Server::Persistence::Taskset.recent).map(&:as_json_with_no_relation)
        end

        desc "Return tasksets that contains failure_exit slave"
        get :failure_slaves do
          paginate(RRRSpec::Server::Persistence::Taskset.has_failed_slaves.recent).map(&:as_json_with_no_relation)
        end

        desc "Return a taskset."
        params { requires :key, type: String, desc: "Taskset key." }
        route_param :key do
          get do
            p_obj = RRRSpec::Server::Persistence::Taskset.where(key: params[:key]).full.first
            if p_obj
              p_obj.as_full_json.update('is_full' => true)
            else
              error!('Not Found', 404)
            end
          end
        end
      end

      namespace :batch do
        resource :tasks do
          desc "Return all tasks in the taskset"
          params { requires :key, type: String, desc: "Taskset key." }
          route_param :key do
            get do
              r_taskset = Taskset.new(params[:key])
              error!('Not Found', 404) unless r_taskset.exist?
              r_taskset.tasks.map(&:to_h)
            end
          end
        end
      end
    end

    module OjFormatter
      def self.call(object, env)
        Oj.dump(object, mode: :compat, time_format: :ruby)
      end
    end

    class APIv2 < Grape::API
      version 'v2', using: :path
      format :json
      formatter :json, OjFormatter

      # For Index

      get '/tasksets/actives' do
        ActiveTaskset.list
      end

      get '/tasksets/recents' do
        paginate(RRRSpec::Server::Persistence::Taskset.recent).map(&:as_json_for_index)
      end

      # For Result Page

      # Notice that this method takes taskset key.
      params { requires :taskset_key, type: String }
      get '/tasksets/:taskset_key' do
        RRRSpec::Server::Persistence::Taskset.includes(tasks: :trials).find_by_key(params[:taskset_key]).as_json_for_result_page
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
        RRRSpec::Server::Persistence::WorkerLog.where(taskset_id: params[:taskset_id]).map(&:as_json_for_result_page)
      end

      params { requires :taskset_id, type: Integer }
      get '/tasksets/:taskset_id/slaves' do
        RRRSpec::Server::Persistence::Slave.includes(:trials).where(taskset_id: params[:taskset_id]).map(&:as_json_for_result_page)
      end
    end
  end
end
