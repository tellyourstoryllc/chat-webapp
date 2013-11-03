App.RoomsIndexView = Ember.View.extend

  isRoomMenuVisible: false

  menuRoom: null

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'documentClick')

  didInsertElement: ->
    $('html').on 'click', @documentClick

  willDestroyElement: ->
    $('html').off 'click', @documentClick

  documentClick: (event) ->
    Ember.run @, ->
      @closeRoomMenu()

  showRoomMenu: (room) ->
    @set('menuRoom', room)
    $menu = @$('.lobby-room-menu')
    $toggle = @$(".room-menu-toggle[data-room-id='#{room.get('id')}']")
    position = $toggle.position()
    $menu.css
      left: position.left
      top: position.top + $toggle.outerHeight()
    $menu.fadeIn(50)
    @set('isRoomMenuVisible', true)

  closeRoomMenu: ->
    @set('menuRoom', null)
    @$('.lobby-room-menu').fadeOut(300)
    @set('isRoomMenuVisible', false)

  isAdminOfMenuRoom: Ember.computed.alias('menuRoom.isCurrentUserAdmin')

  _rowView: (room) ->
    @get('roomsRows').find (view) -> view.get('room') == room

  actions:

    toggleRoomMenu: (room) ->
      if @get('isRoomMenuVisible') && @get('menuRoom') == room
        @closeRoomMenu()
      else
        @showRoomMenu(room)
      return undefined

    renameRoom: ->
      room = @get('menuRoom')
      return unless room?
      @_rowView(room)?.send('renameRoom', room)
      return undefined

    leaveRoom: ->
      room = @get('menuRoom')
      return unless room?

      if room.isPropertyLocked('isDeleted')
        Ember.Logger.warn "I can't delete a room when I'm still waiting for a response from the server."
        return

      return if ! window.confirm("Permanently leave the \"#{room.get('name')}\" room?")

      api = App.get('api')
      url = api.buildURL("/groups/#{room.get('id')}/leave")
      room.withLockedPropertyTransaction url, 'POST', {}, 'isDeleted', =>
        room.set('isDeleted', true)
      , =>
        room.set('isDeleted', false)
      .then =>
        # Make sure the transaction succeeded.
        if room.get('isDeleted')
          # Stop listening for messages.
          room.set('isOpen', false)

      return undefined
