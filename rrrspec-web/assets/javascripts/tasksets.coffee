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
      'tasks/:task_key': 'task'
      'trial/:trial_key': 'trial'
      'slave/:slave_id': 'slave'

  router = new TasksetRouter()

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

    render: ->
      @$el.html(@template(@model.forTemplate()))
      @$('.panel-heading .status').addClass(@model.get('status'))

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
    el: '.tasks'

    initialize: (options) ->
      @subviews = {}
      @$ul = @$('.tasks-list')
      @showHeaders = false
      for model in @collection.models
        @appendItem(model)

      @$('.tasks-heading').click(=>
        @showHeaders = !@showHeaders
        if @showHeaders
          @$('.tasks-heading').text("TASKS")
          for key, view of @subviews
            view.showHeader()
        else
          @$('.tasks-heading').text("FAILED TASKS")
          for key, view of @subviews
            view.hideHeaderIfSuccess()
      )
      router.on('route:task', (taskKey) =>
        view = @subviews[taskKey]
        view.showHeader()
        view.showBody()
        view.scrollIntoView()
      )
      router.on('route:trial', (trialKey) =>
        for key, view of @subviews
          if view.hasTrial(trialKey)
            view.showHeader()
            view.showBody()
            view.scrollIntoViewOfTrial(trialKey)
            break
      )

    appendItem: (model) ->
      view = new TaskView({model: model})
      @subviews[model.attributes.key] = view
      view.render()
      @$ul.append(view.$el)

    render: ->
      for key, view in @subviews
        view.render()

  class TaskView extends Backbone.View
    tagName: 'li'
    className: 'list-group-item'
    template: Handlebars.compile($('#tasks-list-template').html())

    initialize: (options) ->
      @subviews = {}

    hasTrial: (trialKey) -> !!@subviews[trialKey]

    render: ->
      @$el.html(@template(@model.forTemplate()))
      @$el.addClass(@model.get('status'))
      @hideHeaderIfSuccess()
      @$('.tasks-list-item-header').click(=>
        router.navigate("tasks/#{encodeURIComponent(@model.get('key'))}")
        @toggleBody()
      )

      for trial in @model.get('trials')
        @appendTrial(trial)

    appendTrial: (trial) ->
      view = new TrialView({model: trial})
      @subviews[trial.attributes.key] = view
      view.render()
      @$('.trials').append(view.$el)

    showHeader: ->
      @$el.removeClass('hidden')

    hideHeaderIfSuccess: ->
      if @model.isSuccess()
        @$el.addClass('hidden')

    showBody: ->
      @$('.body').collapse('show')

    toggleBody: ->
      @$('.body').collapse('toggle')

    scrollIntoView: -> $('html, body').animate(scrollTop: @$el.offset().top)

    scrollIntoViewOfTrial: (trialKey) ->
      @subviews[trialKey].scrollIntoView()

  class TrialView extends Backbone.View
    className: 'panel'
    template: Handlebars.compile($('#trial-template').html())

    render: ->
      @$el.html(@template(@model.forTemplate()))

    scrollIntoView: -> $('html, body').animate(scrollTop: @$el.offset().top)

  class WorkerLogListView extends Backbone.View
    el: '.worker-logs'

    initialize: (options) ->
      @subviews = []
      @$ul = @$('.worker-logs-list')
      @$('.worker-logs-heading').click(((subviews)-> ->
        for view in subviews
          view.toggle()
      )(@subviews))
      @listenTo(@collection, "add", @appendItem)
      for obj in @collection.models
        @appendItem(obj)

    appendItem: (model) ->
      view = new WorkerLogView({model: model})
      @subviews.push(view)
      view.render()
      @$ul.append(view.$el)

    render: ->
      for view in @subviews
        view.render()

  class WorkerLogView extends Backbone.View
    tagName: 'li'
    className: 'list-group-item hidden'
    template: Handlebars.compile($('#worker-log-template').html())

    render: ->
      @$el.html(@template(@model.forTemplate()))
      body = @$('.body')
      @$('.worker-logs-list-item-header').click(-> body.collapse('toggle'))

    toggle: ->
      @$el.toggleClass('hidden')

  class SlaveListView extends Backbone.View
    el: '.slaves'

    initialize: (options) ->
      @subviews = {}
      @$ul = @$('.slaves-list')
      @$('.slaves-heading').click(=>
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
      @$el.html(@template(@model.forTemplate()))
      body = @$('.body')
      @$('.slaves-list-item-header').click(-> body.collapse('toggle'))

      @$el.addClass(@model.get('status'))

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

  Backbone.history.start()

  if document.URL.match(/\/tasksets\/(.*?)(#.*)?$/)
    taskset = new Taskset({key: RegExp.$1})
    taskset.fetch({
      success: (model, response, options) ->
        if model.isFull()
          tasksetView = new TasksetView({model: model})
          tasksetView.render()
          tasksetView.$el.removeClass('hidden')

          # Force re-route
          fragment = Backbone.history.fragment
          router.navigate('')
          router.navigate(fragment, { trigger: true })
        else
          $('#notfound-modal').modal({keyboard: false})
      error: (model, response, options) ->
        $('#notfound-modal').modal({keyboard: false})
    })
  else
    $('#notfound-modal').modal({keyboard: false})
)
