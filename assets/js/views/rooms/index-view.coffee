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
    $menu.addClass('expand-down')
    @set('isRoomMenuVisible', true)

  closeRoomMenu: ->
    @set('menuRoom', null)
    @$('.lobby-room-menu').removeClass('expand-down')
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
