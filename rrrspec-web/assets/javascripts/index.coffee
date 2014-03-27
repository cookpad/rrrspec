#= require vendor/jquery-1.10.2
#= require vendor/handlebars-v1.3.0
#= require vendor/moment.min
#= require vendor/underscore
#= require vendor/backbone
#= require bootstrap
#= require helpers
#= require models

$(->
  class TasksetsView extends Backbone.View
    initialize: (options) ->
      @subviews = []
      @listenTo(@collection, "add", @appendItem)
      @listenTo(@collection, "reset", @resetItems)
      if @collection.hasPages
        @$('.previous').click(=>
          if @collection.hasPrevious()
            @$('.tasksets').empty()
            @subviews = []
            @collection.fetchPreviousPage(success: -> @render)
          @updatePager()
        )
        @$('.next').click(=>
          @$('.tasksets').empty()
          @subviews = []
          @collection.fetchNextPage(success: -> @render)
          @updatePager()
        )
      @resetItems(@collection)

    appendItem: (model) ->
      view = new TasksetView({model: model})
      @subviews.push(view)
      view.render()
      @$('.tasksets').append(view.$el)

    resetItems: (collection) ->
      @collection = collection
      @$('.tasksets').empty()
      @subviews = []
      for model in collection.models
        @appendItem(model)

    render: ->
      for view in @subviews
        view.render()
      @updatePager()

    updatePager: ->
      if @collection.hasPages
        @$('.pagenum').text("Page #{@collection.currentPage}")
        if @collection.hasPrevious()
          @$('.previous').removeClass('disabled')
        else
          @$('.previous').addClass('disabled')

  class TasksetView extends Backbone.View
    tagName: 'li'
    className: 'list-group-item'
    template: Handlebars.compile($('#taskset-template').html())

    render: ->
      @$el.html(@template(@model.attributes))

  actives = new ActiveTasksets()
  actives.fetch()
  activesView = new TasksetsView({collection: actives, el: '.active-tasksets'})
  activesView.render()

  recents = new RecentTasksets()
  recents.fetch()
  recentsView = new TasksetsView({collection: recents, el: '.recent-tasksets'})
  recentsView.render()
)
