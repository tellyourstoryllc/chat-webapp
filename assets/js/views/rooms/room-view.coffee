App.RoomsRoomView = Ember.View.extend

  group: Ember.computed.alias('controller.model')

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onDragover', 'onDrop')

  didInsertElement: ->
    $(document).on 'dragover', @onDragover
    $(document).on 'drop', @onDrop

  willDestroyElement: ->
    $(document).off 'dragover', @onDragover
    $(document).off 'drop', @onDrop

  onDragover: (event) ->
    Ember.run @, ->
      # When a user drops an image on the page, prevent the page from navigating
      # away to the image.
      event.preventDefault()

  onDrop: (event) ->
    Ember.run @, ->
      event.preventDefault()
      # TODO: This doesn't seem to work in Firefox.
      event.originalEvent.dataTransfer?.items[0]?.getAsString (url) ->
        App.get('roomsContainerView')?.send('attachUrl', url)

  activeRoomChanged: (->
    Ember.run.schedule 'afterRender', @, ->
      @activateRoomLinks()
  ).observes('controller.roomsLoaded', 'controller.model.id')

  activateRoomLinks: ->
    groupId = @get('controller.model.id')
    return unless groupId?

    regexp = new RegExp("/#{groupId}$")
    $('.room-list-item a[href]').each ->
      $link = $(@)
      if regexp.test($link.prop('href') ? '')
        $link.addClass 'active'
      else
        $link.removeClass 'active'
