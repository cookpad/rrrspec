dateFormat = (date)->
  if date
    moment(date).format("YYYY-MM-DD HH:mm:ss z")
  else
    null

dateDuration = (start, finish)->
  moment.duration(moment(finish).diff(moment(start))).humanize()

class @Taskset extends Backbone.Model
  url: -> "/v2/tasksets/#{@get('id')}"

  parse: (obj, options) ->
    obj.created_at = new Date(obj.created_at) if obj.created_at
    obj.finished_at = new Date(obj.finished_at) if obj.finished_at

    obj.tasks = new Tasks(obj.tasks, {parse: true, silent: false})
    obj.worker_logs = new WorkerLogs(obj.worker_logs, {parse: true, silent: false})
    obj.worker_logs.tasksetId = obj.id
    obj.slaves = new Slaves(obj.slaves, {parse: true, silent: false})
    obj.slaves.tasksetId = obj.id
    obj

  isFinished: ->
    status = @get('status')
    return status == 'succeeded' || status == 'cancelled' || status == 'failed'
  outputFetched: -> !!@get('log')
  fetchOutput: ->
    $.getJSON("/v2/tasksets/#{@attributes.id}/log", (data)=>
      @attributes.log = data.log
    )

class @Task extends Backbone.Model
  url: -> "/v2/tasks/#{@get('id')}"
  parse: (obj, options) ->
    if obj.trials
      obj.trials = _.filter(obj.trials, (trial) -> trial['status'])
      obj.trials = _.map(obj.trials, (trial) -> new Trial(trial, {parse: true}))
    obj

  isSuccess: ->
    status = @get('status')
    return status == 'passed' || status == 'pending'

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
  parse: (obj, options) ->
    obj.started_at = new Date(obj.started_at) if obj.started_at
    obj.finished_at = new Date(obj.finished_at) if obj.finished_at
    obj

  outputsFetched: -> !!@attributes.stdout

  fetchOutput: ->
    $.getJSON("/v2/trials/#{@attributes.id}/outputs", (data)=>
      @attributes.stdout = data.stdout
      @attributes.stderr = data.stderr
    )

class @WorkerLog extends Backbone.Model
  parse: (obj, options) ->
    obj.started_at = new Date(obj.started_at)
    obj.rsync_finished_at = new Date(obj.rsync_finished_at) if obj.rsync_finished_at
    obj.setup_finished_at = new Date(obj.setup_finished_at) if obj.setup_finished_at
    obj.rspec_finished_at = new Date(obj.rspec_finished_at) if obj.rspec_finished_at
    obj.log_text = obj.log
    obj

class @WorkerLogs extends Backbone.Collection
  url: -> "/v2/tasksets/#{@tasksetId}/worker_logs"
  parse: (obj, options) ->
    obj.map((worker_log) -> new WorkerLog(worker_log, options))
  fetched: -> !@isEmpty

class @Slave extends Backbone.Model
  parse: (obj, options) ->
    obj.log_text = obj.log
    obj

class @Slaves extends Backbone.Collection
  url: -> "/v2/tasksets/#{@tasksetId}/slaves"
  parse: (obj, options) ->
    obj.map((slave) -> new Slave(slave, options))

class @ActiveTasksets extends Backbone.Collection
  url: "/v2/tasksets/actives"
  parse: (obj, options) ->
    obj.map((taskset) -> new Taskset(taskset, options))

class @RecentTasksets extends Backbone.Collection
  currentPage: 1
  url: -> "/v2/tasksets/recents?page=#{@currentPage}"

  fetchNextPage: ->
    @currentPage++
    @fetch()

  fetchPreviousPage: ->
    if @currentPage != 1
      @currentPage--
    @fetch()

  parse: (obj, options) ->
    obj.map((taskset) -> new Taskset(taskset, options))
