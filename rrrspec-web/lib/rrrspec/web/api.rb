require 'grape'
require 'api-pagination'

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
  end
end
