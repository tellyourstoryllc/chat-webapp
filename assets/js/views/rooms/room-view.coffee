App.RoomsRoomView = Ember.View.extend

  room: Ember.computed.alias('controller.room')

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
      dataTransfer = event.originalEvent.dataTransfer
      if dataTransfer?.files[0]?
        App.get('roomsContainerView')?.send('attachFile', dataTransfer.files[0])
      else
        # TODO: This doesn't seem to work in Firefox.
        dataTransfer?.items[0]?.getAsString (url) ->
          App.get('roomsContainerView')?.send('attachUrl', url)
