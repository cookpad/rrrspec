module RRRSpec
  module Web
    class API < Grape::API
      version 'v1', using: :path
      format :json

      resource :tasksets do
        desc "Return active tasksets"
        get :actives do
          RRRSpec::Server::Taskset.using
        end

        desc "Return recently finished tasksets"
        get :recents do
          paginate(RRRSpec::Server::Taskset.recent).map(&:as_nodetail_json)
        end

        desc "Return tasksets that contains failure_exit slave"
        get :failure_slaves do
          paginate(RRRSpec::Server::Taskset.has_failed_slaves.recent).map(&:as_nodetail_json)
        end

        desc "Return a taskset."
        params { requires :taskset_id, type: Integer, desc: "Taskset id." }
        route_param :taskset_id do
          get do
            p_obj = RRRSpec::Server::Taskset.find(taskset_id).full.first
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
