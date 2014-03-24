#= require vendor/jquery-1.10.2
#= require vendor/handlebars-v1.3.0
#= require vendor/moment.min
#= require vendor/underscore
#= require vendor/backbone
#= require bootstrap
#= require helpers
#= require models

$(->
  class TasksetRouter extends Backbone.Router
    routes:
      'taskset': 'taskset'
      'tasks/:task_id': 'task'
      'trials/:trial_id': 'trial'
      'worker_logs/:worker_log_id': 'worker_log'
      'slaves/:slave_id': 'slave'

  class TasksetView extends Backbone.View
    el: '.taskset'

    initialize: ->
      @headView = new HeadView({model: @model})
      @progressbarView = new ProgressBarView({model: @model})
      @taskListView = new TaskListView({collection: @model.get('tasks')})
      @workerLogListView = new WorkerLogListView({collection: @model.get('worker_logs')})
      @slaveListView = new SlaveListView({collection: @model.get('slaves')})

    render: ->
      @headView.render()
      @progressbarView.render()
      @taskListView.render()
      @workerLogListView.render()
      @slaveListView.render()

  class HeadView extends Backbone.View
    el: '.head'
    template: Handlebars.compile($('#head-template').html())

    initialize: (options) ->
      @shown = false
      router.on('route:taskset', => @show())

    render: ->
      @$el.html(@template(@model.attributes))
      @$('.panel-heading .status').addClass(@model.get('status'))

      @$('.panel-title').click(=>
        router.navigate("taskset")
        @toggle()
      )

    show: ->
      @shown = true
      @$('.taskset-info').collapse('show')
      unless @model.outputFetched()
        @model.fetchOutput().done(=>
          @$('.log').html(@model.get('log'))
        )

    hide: ->
      @shown = false
      @$('.taskset-info').collapse('hide')

    toggle: ->
      @shown = !@shown
      if @shown
        @show()
      else
        @hide()

  class ProgressBarView extends Backbone.View
    el: '.progressbars'

    showBar: (bar, percentage, text) ->
      if percentage == 0
        bar.attr('style', 'width: 0%')
        bar.text('')
      else
        bar.attr('style', "width: #{100*percentage}%")
        bar.text(text)
    hideBar: (bar) -> @showBar(bar, 0, '')

    renderSpecBar: (tasks) ->
      if @model.isFinished()
        @$('.spec-progress').removeClass('progress-striped active')
        @hideBar(@$('.spec-progress-bar'))
        @showBar(@$('.passed-spec-bar'), tasks.numPassedTask/tasks.numTask, tasks.numPassedTask)
        @showBar(@$('.pending-spec-bar'), tasks.numPendingTask/tasks.numTask, tasks.numPendingTask)
        @showBar(@$('.failed-spec-bar'), tasks.numFailedTask/tasks.numTask, tasks.numFailedTask)
      else
        numFinishedTask = tasks.numPassedTask + tasks.numPendingTask + tasks.numFailedTask
        percentage = numFinishedTask/tasks.numTask
        @$('.spec-progress').addClass('progress-striped active')
        @showBar(@$('.spec-progress-bar'), percentage, "#{numFinishedTask}/#{tasks.numTask} (#{100*percentage}%)")
        @hideBar(@$('.passed-spec-bar'))
        @hideBar(@$('.pending-spec-bar'))
        @hideBar(@$('.failed-spec-bar'))

    renderExampleBar: (tasks) ->
      @showBar(@$('.passed-example-bar'), tasks.numPassedExample/tasks.numExample, tasks.numPassedExample)
      @showBar(@$('.pending-example-bar'), tasks.numPendingExample/tasks.numExample, tasks.numPendingExample)
      @showBar(@$('.failed-example-bar'), tasks.numFailedExample/tasks.numExample, tasks.numFailedExample)

    render: ->
      tasks = @model.get('tasks')
      @renderSpecBar(tasks)
      @renderExampleBar(tasks)

  class TaskListView extends Backbone.View
    el: '.tasklist'

    initialize: (options) ->
      @subviews = {}
      @$ul = @$('.tasklist-list')
      @showAllHeader = false
      @$('.panel-heading').click(=>
        @showAllHeader = !@showAllHeader
        if @showAllHeader
          for key, view of @subviews
            view.showHeader()
        else
          for key, view of @subviews
            view.hideHeaderIfSuccess()
      )
      for model in @collection.models
        @appendItem(model)
      router.on('route:task', (taskId) =>
        view = @subviews[taskId]
        view.showHeader()
        view.showBody()
        view.scrollIntoView()
      )
      router.on('route:trial', (trialId) =>
        for key, view of @subviews
          if view.hasTrial(trialId)
            view.showHeader()
            view.showBody()
            view.scrollIntoViewOfTrial(trialId)
            break
      )

    appendItem: (model) ->
      view = new TaskView({model: model})
      @subviews[model.attributes.id] = view
      view.render()
      @$ul.append(view.$el)

    render: ->
      for key, view in @subviews
        view.render()

  class TaskView extends Backbone.View
    tagName: 'li'
    className: 'list-group-item'
    template: Handlebars.compile($('#task-template').html())

    initialize: (options) ->
      @subviews = {}
      @bodyShowing = false

    render: ->
      @$el.html(@template(@model.attributes))
      @$el.addClass(@model.get('status'))
      @hideHeaderIfSuccess()
      @$('.header').click(=>
        router.navigate("tasks/#{@model.get('id')}")
        @toggleBody()
      )
      for trial in @model.get('trials')
        @appendTrial(trial)

    appendTrial: (trial) ->
      view = new TrialView({model: trial})
      @subviews[trial.attributes.id] = view
      view.render()
      @$('.trials').append(view.$el)

    showHeader: ->
      @$el.removeClass('hidden')

    hideHeaderIfSuccess: ->
      if @model.isSuccess()
        @$el.addClass('hidden')

    showBody: ->
      @bodyShowing = true
      for key, view of @subviews
        view.showBody()
      @$('.body').collapse('show')
      @scrollIntoView()

    hideBody: ->
      @bodyShowing = false
      @$('.body').collapse('hide')

    toggleBody: ->
      @bodyShowing = !@bodyShowing
      if @bodyShowing
        @showBody()
      else
        @hideBody()

    hasTrial: (trialId) -> !!@subviews[trialId]

    scrollIntoView: -> $('html, body').animate(scrollTop: @$el.offset().top)

    scrollIntoViewOfTrial: (trialId) ->
      @subviews[trialId].scrollIntoView()

  class TrialView extends Backbone.View
    className: 'panel'
    template: Handlebars.compile($('#trial-template').html())

    render: ->
      @$el.html(@template(@model.attributes))

    showBody: ->
      unless @model.outputsFetched()
        @model.fetchOutput().done(=>
          @$('.stdout').html(@model.get('stdout'))
          @$('.stderr').html(@model.get('stderr'))
        )

    scrollIntoView: -> $('html, body').animate(scrollTop: @$el.offset().top)

  class WorkerLogListView extends Backbone.View
    el: '.worker-logs'

    initialize: (options) ->
      @showAllHeader = false
      @$('.panel-heading').click(=> @toggle())

      @resetItems(@collection)

    resetItems: (collection) ->
      @collection = collection
      @$('.worker-logs-list').html('')
      @subviews = []
      @listenTo(collection, "add", @appendItem)
      @listenTo(collection, "reset", @resetItems)
      for model in collection.models
        @appendItem(model)

    appendItem: (model) ->
      view = new WorkerLogView({model: model})
      @subviews.push(view)
      view.render()
      @$('.worker-logs-list').append(view.$el)

    render: ->
      for view in @subviews
        view.render()

    show: ->
      unless @collection.fetched()
        @collection.fetch({reset: true}).done(=>
          @$('.worker-logs-list').collapse('show')
        )
      else
        @$('.worker-logs-list').collapse('show')

    hide: ->
      @$('.worker-logs-list').collapse('hide')

    toggle: ->
      @showAllHeader = !@showAllHeader
      if @showAllHeader
        @show()
      else
        @hide()

  class WorkerLogView extends Backbone.View
    tagName: 'li'
    className: 'list-group-item'
    template: Handlebars.compile($('#worker-log-template').html())

    render: ->
      @$el.html(@template(@model.attributes))
      @$('.header').click(=> @$('.body').collapse('toggle'))

  class SlaveListView extends Backbone.View
    el: '.slaves'

    initialize: (options) ->
      @subviews = {}
      @$ul = @$('.slaves-list')
      @$('.panel-heading').click(=>
        for key, view of @subviews
          view.toggle()
      )
      @listenTo(@collection, "add", @appendItem)
      for obj in @collection.models
        @appendItem(obj)
      router.on('route:slave', (slaveId) =>
        for key, view of @subviews
          view.show()
        target = @subviews[slaveId]
        target.scrollIntoView()
        target.showBody()
      )

    appendItem: (model) ->
      view = new SlaveView({model: model})
      @subviews[model.attributes.key] = view
      view.render()
      @$ul.append(view.$el)

    render: ->
      for key, view of @subviews
        view.render()

  class SlaveView extends Backbone.View
    tagName: 'li'
    className: 'list-group-item hidden'
    template: Handlebars.compile($('#slave-template').html())

    render: ->
      @$el.html(template(@model.attributes))
      body = @$('.body')
      @$('.header').click(-> body.collapse('toggle'))

      switch @model.get('status')
        when 'normal_exit' then @$el.addClass('normal')
        when 'timeout_exit' then @$el.addClass('timeout')
        when 'failure_exit' then @$el.addClass('failure')

    scrollIntoView: ->
      $('html, body').animate(
        scrollTop: @$el.offset().top
      )

    show: ->
      @$el.removeClass('hidden')

    showBody: ->
      @$('.body').collapse('show')

    toggle: ->
      @$el.toggleClass('hidden')

  router = new TasksetRouter()
  Backbone.history.start()

  if document.URL.match(/\/tasksets\/(.*?)(#.*)?$/)
    taskset = new Taskset({id: RegExp.$1})
    taskset.fetch({
      success: (model, response, options) ->
        tasksetView = new TasksetView({model: model})
        tasksetView.render()
        tasksetView.$el.removeClass('hidden')

        # Force re-route
        fragment = Backbone.history.fragment
        router.navigate('')
        router.navigate(fragment, {trigger: true})
      error: (model, response, options) ->
        $('#notfound-modal').modal({keyboard: false})
    })
  else
    $('#notfound-modal').modal({keyboard: false})
)
