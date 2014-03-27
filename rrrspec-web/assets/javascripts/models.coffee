class @Taskset extends Backbone.Model
  url: -> "/v1/tasksets/#{encodeURIComponent(@get('key'))}"

  parse: (obj, options) ->
    obj.created_at = new Date(obj.created_at) if obj.created_at
    obj.finished_at = new Date(obj.finished_at) if obj.finished_at
    obj.slaves = new Slaves(obj.slaves, {parse: true, silent: false})
    obj.tasks = new Tasks(obj.tasks, {parse: true, silent: false})
    obj.worker_logs = new WorkerLogs(obj.worker_logs, {parse: true, silent: false})
    obj.log_text = obj.log
    obj

  isFull: -> !!@get('is_full')
  isFinished: -> !!@get('finished_at')

  forTemplate: -> @toJSON()

class @Task extends Backbone.Model
  url: -> "/v1/tasks/#{encodeURIComponent(@get('key'))}"
  parse: (obj, options) ->
    if obj.trials
      obj.trials = _.filter(obj.trials, (trial) -> trial['status'])
      obj.trials = _.map(obj.trials, (trial) -> new Trial(trial, {parse: true}))
    obj

  numExamples: ->
    passed = null
    pending = null
    failed = null
    for trial in @get('trials')
      switch trial.get('status')
        when 'passed' then passed = trial
        when 'pending' then pending = trial
        when 'failed' then failed = trial

    preferred = null
    if passed then preferred = passed
    else if pending then preferred = pending
    else if failed then preferred = failed
    else
      return [0, 0, 0]
    return [preferred.get('passed'), preferred.get('pending'), preferred.get('failed')]

  forTemplate: -> @toJSON()

class @Tasks extends Backbone.Collection
  initialize: (options) ->
    @numTask = 0
    @numPassedTask = 0
    @numPendingTask = 0
    @numFailedTask = 0
    @numRunningTask = 0
    @numExample = 0
    @numPassedExample = 0
    @numPendingExample = 0
    @numFailedExample = 0
    @listenTo(@, "add", @addItem)

  parse: (obj, options) ->
    obj.map((task) -> new Task(task, options))

  addItem: (model, collection, options) ->
    @numTask += 1
    switch model.get('status')
      when 'running' then @numRunningTask += 1
      when 'passed' then @numPassedTask += 1
      when 'pending' then @numPendingTask += 1
      when 'failed' then @numFailedTask += 1
    switch model.get('status')
      when 'passed', 'pending', 'failed'
        [passed, pending, failed] = model.numExamples()
        @numExample += passed + pending + failed
        @numPassedExample += passed
        @numPendingExample += pending
        @numFailedExample += failed

class @Trial extends Backbone.Model
  url: -> "/v1/trials/#{encodeURIComponent(@get('key'))}"
  parse: (obj, options) ->
    obj.started_at = new Date(obj.started_at) if obj.started_at
    obj.finished_at = new Date(obj.finished_at) if obj.finished_at
    obj
  forTemplate: -> @toJSON()

class @WorkerLog extends Backbone.Model
  url: -> "/v1/worker_logs/#{encodeURIComponent(@get('key'))}"
  parse: (obj, options) ->
    obj.started_at = new Date(obj.started_at)
    obj.rsync_finished_at = new Date(obj.rsync_finished_at) if obj.rsync_finished_at
    obj.setup_finished_at = new Date(obj.setup_finished_at) if obj.setup_finished_at
    obj.finished_at = new Date(obj.finished_at) if obj.finished_at
    obj.log_text = obj.log
    obj

  forTemplate: -> @toJSON()

class @WorkerLogs extends Backbone.Collection
  parse: (obj, options) ->
    obj.map((worker_log) -> new WorkerLog(worker_log, options))

class @Slave extends Backbone.Model
  url: -> "/v1/slaves/#{encodeURIComponent(@get('key'))}"
  parse: (obj, options) ->
    obj.log_text = obj.log
    obj

  forTemplate: ->
    j = @toJSON()
    j['trials'] = _.map(j['trials'], (trial) ->
      trial['encoded_key'] = encodeURIComponent(trial['key'])
      trial
    )
    j

class @Slaves extends Backbone.Collection
  parse: (obj, options) ->
    obj.map((slave) -> new Slave(slave, options))

class @ActiveTasksets extends Backbone.Collection
  url: "/v1/tasksets/actives"
  parse: (obj, options) ->
    obj.map((taskset) -> new Taskset(taskset, options))

class @RecentTasksets extends Backbone.Collection
  currentPage: 1
  url: -> "/v1/tasksets/recents?page=#{@currentPage}"

  fetchNextPage: ->
    @currentPage++
    @fetch()

  fetchPreviousPage: ->
    if @currentPage != 1
      @currentPage--
    @fetch()

  parse: (obj, options) ->
    obj.map((taskset) -> new Taskset(taskset, options))

class @SlaveFailedTasksets extends Backbone.Collection
  currentPage: 1
  url: -> "/v1/tasksets/failure_slaves?page=#{@currentPage}"

  fetchNextPage: ->
    @currentPage++
    @fetch()

  fetchPreviousPage: ->
    if @currentPage != 1
      @currentPage--
    @fetch()

  parse: (obj, options) ->
    obj.map((taskset) -> new Taskset(taskset, options))
