class TasksetsView extends Backbone.View
  initialize: (options) ->
    @subviews = []
    @listenTo(@collection, "add", @appendItem)
    @$('.previous').click(=>
      @$('.tasksets').empty()
      @subviews = []
      @collection.fetchPreviousPage(success: -> @render)
    )
    @$('.next').click(=>
      @$('.tasksets').empty()
      @subviews = []
      @collection.fetchNextPage(success: -> @render)
    )
    @render()
    for obj in @collection.models
      @appendItem(obj)

  appendItem: (model) ->
    view = new TasksetView({model: model})
    @subviews.push(view)
    view.render()
    @$('.tasksets').append(view.$el)

  render: ->
    for view in @subviews
      view.render()

class TasksetView extends Backbone.View
  tagName: 'li'
  className: 'list-group-item'

  render: ->
    @$el.html(Mustache.render($('#taskset-template').html(), @model.forTemplate()))

$(->
  actives = new ActiveTasksets()
  actives.fetch()
  activesView = new TasksetsView({collection: actives, el: '.active-tasksets'})
  activesView.render()

  recents = new RecentTasksets()
  recents.fetch()
  recentsView = new TasksetsView({collection: recents, el: '.recent-tasksets'})
  recentsView.render()

  slave_failed = new SlaveFailedTasksets()
  slave_failed .fetch()
  recentsView = new TasksetsView({collection: slave_failed, el: '.slave-failed-tasksets'})
  recentsView.render()
)
