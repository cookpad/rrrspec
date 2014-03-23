taskIdFromTrialId = (trialId)->
  trialId.match(/^(.*):trial:/)[1]

class TasksetRouter extends Backbone.Router
  routes:
    'slave/:slave_id': 'slave'
    'trial/:trial_id': 'trial'

router = new TasksetRouter()
Backbone.history.start()

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

  render: ->
    @$el.html(@template(@model.attributes))
    @$('.panel-heading .status').addClass(
      switch @model.get('status')
        when 'running' then 'label-active'
        when 'succeeded' then 'label-success'
        when 'cancelled' then 'label-warning'
        when 'failed' then 'label-danger'
        else ''
    )

class ProgressBarView extends Backbone.View
  el: '.progressbars'

  render: ->
    tasks = @model.get('tasks')
    if @model.isFinished()
      @$('.spec-progress').removeClass('progress-striped active')
      @$('.spec-progress-bar').attr('style', 'width: 0%')
      @$('.spec-progress-bar').text('')
      if tasks.numPassedTask > 0
        @$('.passed-spec-bar').attr('style', "width: #{100*tasks.numPassedTask/tasks.numTask}%")
        @$('.passed-spec-bar').text(tasks.numPassedTask)
      if tasks.numPendingTask > 0
        @$('.pending-spec-bar').attr('style', "width: #{100*tasks.numPendingTask/tasks.numTask}%")
        @$('.pending-spec-bar').text(tasks.numPendingTask)
      if tasks.numFailedTask > 0
        @$('.failed-spec-bar').attr('style', "width: #{100*tasks.numFailedTask/tasks.numTask}%")
        @$('.failed-spec-bar').text(tasks.numFailedTask)
    else
      numFinishedTask = tasks.numPassedTask + tasks.numPendingTask + tasks.numFailedTask
      percentage = 100*numFinishedTask/tasks.numTask
      @$('.spec-progress').addClass('progress-striped active')
      @$('.spec-progress-bar').attr('style', "width: #{percentage}%")
      @$('.spec-progress-bar').text("#{numFinishedTask}/#{tasks.numTask}(#{percentage}%)")
      @$('.passed-spec-bar').attr('style', 'width: 0%')
      @$('.passed-spec-bar').text('')
      @$('.pending-spec-bar').attr('style', 'width: 0%')
      @$('.pending-spec-bar').text('')
      @$('.failed-spec-bar').attr('style', 'width: 0%')
      @$('.failed-spec-bar').text('')

    if tasks.numPassedExample > 0
      @$('.passed-example-bar').attr('style', "width: #{100*tasks.numPassedExample/tasks.numExample}%")
      @$('.passed-example-bar').text(tasks.numPassedExample)
    else
      @$('.passed-example-bar').attr('style', "width: 0%")
      @$('.passed-example-bar').text('')
    if tasks.numPendingExample > 0
      @$('.pending-example-bar').attr('style', "width: #{100*tasks.numPendingExample/tasks.numExample}%")
      @$('.pending-example-bar').text(tasks.numPendingExample)
    else
      @$('.pending-example-bar').attr('style', "width: 0%")
      @$('.pending-example-bar').text('')
    if tasks.numFailedExample > 0
      @$('.failed-example-bar').attr('style', "width: #{100*tasks.numFailedExample/tasks.numExample}%")
      @$('.failed-example-bar').text(tasks.numFailedExample)
    else
      @$('.failed-example-bar').attr('style', "width: 0%")
      @$('.failed-example-bar').text('')

class TaskListView extends Backbone.View
  el: '.tasklist'

  initialize: (options) ->
    @subviews = {}
    @$ul = @$('.tasklist-list')
    @heading = @$('.panel-heading')
    @heading.click(=>
      if @heading.text() == "FAILED TASKS"
        @heading.text("TASKS")
      else
        @heading.text("FAILED TASKS")
      for key, view of @subviews
        view.toggle()
    )
    for model in @collection.models
      @appendItem(model)
    router.on('route:trial', (trialId) =>
      taskId = taskIdFromTrialId(trialId)
      target = @subviews[taskId]
      target.show()
      target.showBody()
      target.scrollIntoViewOfTrial(trialId)
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

  initialize: (options) ->
    @subviews = {}
  render: ->
    @$el.html(@template(@model.attributes))
    body = @$('.body')
    @$('.header').click(-> body.collapse('toggle'))
    switch @model.get('status')
      when 'running' then @$el.addClass('running')
      when 'passed' then @$el.addClass('passed')
      when 'pending' then @$el.addClass('pending')
      when 'failed' then @$el.addClass('failed')

    trialsContainer = @$('.trials')
    for trial in @model.get('trials')
      view = new TrialView({model: trial})
      @subviews[trial.attributes.key] = view
      view.render()
      trialsContainer.append(view.$el)

    if @shouldHide()
      @$el.addClass('hidden')

  shouldHide: ->
    status = @model.get('status')
    return status == 'passed' || status == 'pending'

  toggle: ->
    if @shouldHide()
      @$el.toggleClass('hidden')

  show: ->
    @$el.removeClass('hidden')

  showBody: ->
    @$('.body').collapse('show')

  scrollIntoViewOfTrial: (trialId) ->
    @subviews[trialId].scrollIntoView()

class TrialView extends Backbone.View
  className: 'panel'

  render: ->
    @$el.html(@template(@model.attributes))

  scrollIntoView: ->
    $('html, body').animate(
      scrollTop: @$el.offset().top
    )

class WorkerLogListView extends Backbone.View
  el: '.worker-logs'

  initialize: (options) ->
    @subviews = []
    @$ul = @$('.worker-logs-list')
    @$('.panel-heading').click(((subviews)-> ->
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

  render: ->
    @$el.html(@template(@model.attributes))
    body = @$('.body')
    @$('.header').click(-> body.collapse('toggle'))

  toggle: ->
    @$el.toggleClass('hidden')

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

injectTemplate = ->
  HeadView.template = Handlebars.compile($('#head-template').html())
  TaskView.template = Handlebars.compile($('#task-template').html())
  TrialView.template = Handlebars.compile($('#trial-template').html())
  WorkerLogView.template = Handlebars.compile($('#worker-log-template').html())
  SlaveView.template = Handlebars.compile($('#slave-template').html())

$(->
  injectTemplate()
  if document.URL.match(/\/tasksets\/(.*?)(#.*)?$/)
    taskset = new Taskset({id: RegExp.$1})
    taskset.fetch({
      success: (model, response, options) ->
        if model.isFull()
          tasksetView = new TasksetView({model: model})
          tasksetView.render()
          tasksetView.$el.removeClass('hidden')

          # Force re-route
          fragment = Backbone.history.fragment
          router.navigate('')
          router.navigate(fragment, {trigger: true})
        else
          $('#notfound-modal').modal({keyboard: false})
      error: (model, response, options) ->
        $('#notfound-modal').modal({keyboard: false})
    })
  else
    $('#notfound-modal').modal({keyboard: false})
)
