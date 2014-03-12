# Actions: goToRoom
App.UsersListComponent = Ember.Component.extend
  classNames: ['users-list-component']

  # Bind this to the list of users.
  users: null

  allUsers: null

  sortedUsers: null

  activeRoom: null

  # Currently we do not support these values changing after creation.
  showStatus: true
  alwaysShowAvatar: false

  prevStatusByGuid: null
  prevClientTypeByGuid: null

  animationQueue: null
  isAnimationRunning: false

  _users: null
  _allUsers: null

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onResize')
    @setProperties
      prevStatusByGuid: {}
      prevClientTypeByGuid: {}
      animationQueue: []

  didInsertElement: ->
    @insertRows(@get('allUsers'))
    $(window).on 'resize', @onResize

  willDestroyElement: ->
    $(window).off 'resize', @onResize

    # TODO: remove all observers.  We never actually destroy this element
    # currently.

  onResize: _.throttle (event) ->
    Ember.run @, ->
      # Showing and hiding the members sidebar can cause position issues.
      @updatePositions()
      return undefined
  , 500

  allUsersArrayDidChange: (->
    allUsers = @get('allUsers')
    observingAllUsers = @get('_allUsers')
    if allUsers != observingAllUsers
      opts = willChange: 'allUsersWillChange', didChange: 'allUsersDidChange'
      observingAllUsers?.removeArrayObserver(@, opts)
      allUsers?.addArrayObserver(@, opts)
      @set('_allUsers', allUsers)

    # Handle as if it were a change.
    if observingAllUsers?
      @usersWillChange(observingAllUsers, 0, observingAllUsers.length ? observingAllUsers.get('length'), 0)
    if allUsers?
      @allUsersDidChange(allUsers, 0, 0, allUsers.length ? allUsers.get('length'))
  ).observes('allUsers').on('didInsertElement')

  allUsersWillChange: (allUsers, start, removeCount, addCount) ->
    usersToRemove = allUsers.slice(start, start + removeCount)
    @destroyUsers(usersToRemove)

  allUsersDidChange: (allUsers, start, removeCount, addCount) ->
    usersToAdd = allUsers.slice(start, start + addCount)
    @buildUsers(usersToAdd)

  destroyUsers: (users) ->
    return unless @currentState == Ember.View.states.inDOM
    $container = @$()
    $es = Ember.$()
    users.forEach (room) =>
      $es = $es.add("[data-room-guid='#{Ember.guidFor(room)}']", $container)
    $es.remove()

  buildUsers: (users) ->
    return unless @currentState == Ember.View.states.inDOM
    # Use a document fragment and insert once at the end to reduce reflows.
    fragment = document.createDocumentFragment()
    users.forEach (room) =>
      @insertUserRow(room, fragment)
    @$('.room-members').append(fragment)

  usersArrayDidChange: (->
    users = @get('users')
    observingUsers = @get('_users')
    if users != observingUsers
      opts = willChange: 'usersWillChange', didChange: 'usersDidChange'
      observingUsers?.removeArrayObserver(@, opts)
      users?.addArrayObserver(@, opts)
      @set('_users', users)

    # Handle as if it were a change.
    if observingUsers? && ! users?
      @usersWillChange(observingUsers, 0, observingUsers.length ? observingUsers.get('length'), 0)
    else if users? && ! observingUsers?
      @usersDidChange(users, 0, 0, users.length ? users.get('length'))
    else if users? && observingUsers?
      usersToRemove = App.Util.arrayWithoutArray(observingUsers, users)
      usersToAdd = App.Util.arrayWithoutArray(users, observingUsers)
      @queueAnimation @, 'hideUsers', usersToRemove
      @queueAnimation @, 'updatePositions'
      @queueAnimation @, 'showUsers', usersToAdd
    @runAnimations()
  ).observes('users').on('didInsertElement')

  usersWillChange: (users, start, removeCount, addCount) ->
    usersToRemove = users.slice(start, start + removeCount)
    if ! Ember.isEmpty(usersToRemove)
      @queueAnimation @, 'hideUsers', usersToRemove
      @queueAnimation @, 'updatePositions'
      @runAnimations()

  usersDidChange: (users, start, removeCount, addCount) ->
    usersToAdd = users.slice(start, start + addCount)
    if ! Ember.isEmpty(usersToAdd)
      @queueAnimationOnce @, 'updatePositions'
      @queueAnimation @, 'showUsers', usersToAdd
      @runAnimations()

  hideUsers: (users) ->
    return unless @currentState == Ember.View.states.inDOM
    return if Ember.isEmpty(users)
    $container = @$()
    $es = Ember.$()
    users.forEach (room) =>
      $es = $es.add("[data-room-guid='#{Ember.guidFor(room)}']", $container)
    $es.addClass('hidden')

  showUsers: (users) ->
    return unless @currentState == Ember.View.states.inDOM
    return if Ember.isEmpty(users)
    $container = @$()
    $es = Ember.$()
    users.forEach (room) =>
      $es = $es.add("[data-room-guid='#{Ember.guidFor(room)}']", $container)
    $es.removeClass('hidden')

  queueAnimation: (context, method, args...) ->
    @get('animationQueue').pushObject([context, method, args])
    undefined

  queueAnimationOnce: (context, method, args...) ->
    queue = @get('animationQueue')
    objToQueue = [context, method, args]
    if ! _.isEqual(queue.get('lastObject'), objToQueue)
      queue.pushObject(objToQueue)
    undefined

  runAnimations: ->
    return if @get('isAnimationRunning')
    Ember.run.schedule 'afterRender', @, 'continueAnimations'

  continueAnimations: ->
    animations = @get('animationQueue')
    obj = animations.shiftObject()
    if obj?
      @set('isAnimationRunning', true)
      [context, method, args] = obj
      if typeof method == 'string'
        method = context[method]
      args ?= []
      method.apply(context, args)
      Ember.run.later @, 'continueAnimations', 200
    else
      @set('isAnimationRunning', false)
    undefined

  usersSortDidChange: (->
    # If they're not the same array, the entire list will be updated later.
    if @get('users') == @get('_users')
      @queueAnimationOnce @, 'updatePositions'
      @runAnimations()
  ).observes('users.@each.status', 'users.@each.name')

  updatePositions: ->
    return unless @currentState == Ember.View.states.inDOM
    room = @get('room')
    # Get the users sorted by status and name.
    arrangedUsers = @get('sortedUsers')
    return unless arrangedUsers?
    # Sanity check.
    len = arrangedUsers?.get('length')
    if len != @get('users.length')
      Ember.Logger.error "users length doesn't match room members length"
      return

    top = 0
    arrangedUsers.forEach (room, i) ->
      $item = @$("[data-room-guid='#{Ember.guidFor(room)}']")
      itemHeight = $item.outerHeight() ? 36
      $item.css
        top: top
      top += itemHeight

    # Set height so it can be scrollable.
    @$('.room-members').css height: top

  insertRows: (users) ->
    # TODO: use a document fragment and insert once at the end.

    e = document.createElement('ul')
    $e = $(e)
    $e.addClass('room-members')

    users.forEach (user) =>
      @insertUserRow(user, e)

    $container = @$()
    $container.append(e)

  insertUserRow: (user, e) ->
    $e = $(e)
    room = user
    roomId = App.OneToOne.idFromUserIds(user.get('id'), App.get('currentUser.id'))
    rooms = @get('users')

    # <li class='room-member'>
    li = document.createElement('li')
    $li = $(li)
    $li.addClass('room-member')
    if ! rooms? || ! rooms.contains(user)
      $li.addClass('hidden')
    $li.appendTo(e)

    # For ourselves.
    $li.attr('data-id', roomId)
    $li.attr('data-room-guid', Ember.guidFor(room))

    # {{#link-to 'rooms.room' user classNames='room-member-link'
    #   classNameBindings='view.showAvatars::avatars-off'}}
    a = document.createElement('a')
    a.href = "/rooms/#{roomId}"
    $a = $(a)
    $a.addClass('room-member-link')
    if ! @get('showAvatars')
      $a.addClass('avatars-off')
    $a.click (event) =>
      return if App.Util.isUsingModifierKey(event)
      event.preventDefault()
      @sendAction('goToRoom', roomId)
      return undefined
    $a.appendTo(li)

    # {{room-avatar room=user showStatus=true}}
    avatar = document.createElement('span')
    $avatar = $(avatar)
    $avatar.addClass('room-avatar').addClass('small-avatar')
    room.addObserver('status', @, 'statusDidChange')
    # @one 'willDestroyElement', =>
    #   room.removeObserver('status', @, 'statusDidChange')
    @updateStatus(room, $avatar) # Update immediately.
    room.addObserver('clientType', @, 'clientTypeDidChange')
    # @one 'willDestroyElement', =>
    #   room.removeObserver('clientType', @, 'clientTypeDidChange')
    @updateClientType(room, $avatar) # Update immediately.
    # TODO: observers.
    if ! @get('showStatus')
      $avatar.addClass('no-status')
    if ! @get('showAvatars')
      $avatar.addClass('avatars-off')
    if room instanceof App.Group
      $avatar.addClass('group')
    if @get('alwaysShowAvatar')
      $avatar.addClass('always-show-avatar')
    avatarUrlObserver = =>
      url = room.get('avatarUrl')
      text = if url? then "url('#{url}')" else null
      $avatar.css('background-image', text)
    room.addObserver('avatarUrl', avatarUrlObserver)
    # @one 'willDestroyElement', =>
    #   room.removeObserver('avatarUrl', avatarUrlObserver)
    avatarUrlObserver() # Trigger immediately.
    $avatar.appendTo(a)

    # <div class='room-member-info-cell'>
    infoCell = document.createElement('div')
    $infoCell = $(infoCell)
    $infoCell.addClass('room-member-info-cell')
    $infoCell.appendTo(a)

    # <span class='username'>{{user.name}}</span>
    name = document.createElement('span')
    $name = $(name)
    $name.addClass('username')
    nameObserver = =>
      name = room.get('name') ? ''
      $name.text(name)
    room.addObserver('name', nameObserver)
    # @one 'willDestroyElement', =>
    #   room.removeObserver('name', nameObserver)
    nameObserver() # Trigger immediately.
    $name.appendTo(infoCell)

    # Add a naturally breaking space.
    space = document.createTextNode(' ')
    infoCell.appendChild(space)

    # {{#if room.isUserAnAdmin(user)}}
    #   <span class='admin-indicator' title='Room Admin'>*</span>
    # {{/if}}
    if room instanceof App.User
      admin = document.createElement('span')
      $admin = $(admin)
      $admin.addClass('admin-indicator')
      $admin.text('*').attr('title', 'Room Admin')
      adminObserver = =>
        activeRoom = @get('activeRoom')
        if activeRoom?.isUserAnAdmin(room)
          $admin.removeClass('hidden')
        else
          $admin.addClass('hidden')
      @addObserver('activeRoom.admins.[]', @_scheduledAfterRender(adminObserver))
      # @one 'willDestroyElement', =>
      #   @removeObserver('activeRoom.admins.[]', adminObserver)
      adminObserver() # Trigger immediately.
      $admin.appendTo(infoCell)

    # Add a naturally breaking space.
    space = document.createTextNode(' ')
    infoCell.appendChild(space)

    # {{#if user.shouldDisplayIdleDuration}}
    #   <span class='idle-duration'>{{duration user.mostRecentIdleDuration}}</span>
    # {{/if}}
    idle = document.createElement('span')
    $idle = $(idle)
    $idle.addClass('idle-duration')
    mostRecentIdleDurationObserver = =>
      text = null
      duration = room.get('mostRecentIdleDuration')
      if Ember.typeOf(duration) == 'number'
        seconds = Math.round(duration)
        text = moment.duration(seconds, 'seconds').humanize()
      $idle.text(text)
      # Idle text can affect the item height.
      if room.get('shouldDisplayIdleDuration')
        @queueAnimationOnce @, 'updatePositions'
        @runAnimations()
    shouldDisplayIdleDurationObserver = =>
      if room.get('shouldDisplayIdleDuration')
        # Only observe the idle duration when we're actually showing it.
        mostRecentIdleDurationObserver() # Trigger immediately.
        room.addObserver('mostRecentIdleDuration', mostRecentIdleDurationObserver)
        # TODO: Remove observer on destroy.
        $idle.removeClass('hidden')
      else
        $idle.addClass('hidden')
        room.removeObserver('mostRecentIdleDuration', mostRecentIdleDurationObserver)
      # Idle text can affect the item height.
      @queueAnimationOnce @, 'updatePositions'
      @runAnimations()
    room.addObserver('shouldDisplayIdleDuration', shouldDisplayIdleDurationObserver)
    # @one 'willDestroyElement', =>
    #   room.removeObserver('shouldDisplayIdleDuration', shouldDisplayIdleDurationObserver)
    shouldDisplayIdleDurationObserver() # Trigger immediately.
    $idle.appendTo(infoCell)

    # {{#if user.statusText}}
    #   <div class='status-text'>{{user.statusText}}</div>
    # {{/if}}
    statusText = document.createElement('div')
    $statusText = $(statusText)
    $statusText.addClass('status-text')
    room.addObserver('statusText', @, 'statusTextDidChange')
    # @one 'willDestroyElement', =>
    #   room.removeObserver('statusText', @, 'statusTextDidChange')
    @updateStatusText(room, $statusText) # Update immediately.
    $statusText.appendTo(infoCell)

    # <div class='clearfix'></div>
    clearfix = document.createElement('div')
    $clearfix = $(clearfix)
    $clearfix.addClass('clearfix')
    $clearfix.appendTo(a)

  statusDidChange: (room) ->
    sel = "[data-room-guid='#{Ember.guidFor(room)}'] .small-avatar"
    $avatar = @$(sel)
    if ! $avatar?
      Ember.Logger.error "Couldn't find avatar element", room?.get('id'), sel, $(sel), $avatar, @
      if @currentState == Ember.View.states.inDOM
        Ember.logger.log "falling back to global selector"
        $avatar = $(sel)
    @updateStatus(room, $avatar)

  updateStatus: (room, $avatar) ->
    prevStatusByGuid = @get('prevStatusByGuid')
    if room.get('hasStatusIcon')
      status = room.get('status')
    roomGuid = Ember.guidFor(room)
    if (prevStatus = prevStatusByGuid[roomGuid])?
      $avatar?.removeClass(prevStatus)
    $avatar?.addClass(status) if status?
    prevStatusByGuid[roomGuid] = status

  clientTypeDidChange: (room) ->
    @updateClientType(room, @$("[data-room-guid='#{Ember.guidFor(room)}'] .small-avatar"))

  updateClientType: (room, $avatar) ->
    prevClientTypeByGuid = @get('prevClientTypeByGuid')
    if room.get('hasStatusIcon')
      clientType = room.get('clientType')
    roomGuid = Ember.guidFor(room)
    if (prevClientType = prevClientTypeByGuid[roomGuid])?
      $avatar?.removeClass(prevClientType)
    $avatar?.addClass(clientType) if clientType?
    prevClientTypeByGuid[roomGuid] = clientType

  statusTextDidChange: (room) ->
    @updateStatusText(room, @$("[data-room-guid='#{Ember.guidFor(room)}'] .status-text"))

  updateStatusText: (room, $e) ->
    return unless $e?
    statusText = room.get('statusText')
    if statusText?
      $e.text(statusText)
      $e.show()
    else
      $e.text('')
      $e.hide()
    # Status text can affect the item height.
    @queueAnimationOnce @, 'updatePositions'
    @runAnimations()

  showAvatars: (->
    App.get('preferences.clientWeb.showAvatars')
  ).property('App.preferences.clientWeb.showAvatars')

  showAvatarsDidChange: (->
    # Showing/hiding avatars can affect the item height.
    @queueAnimationOnce @, 'updatePositions'
    @runAnimations()
  # Note: Need to observe the actual property, not the computed property for
  # this observer to trigger.
  ).observes('App.preferences.clientWeb.showAvatars')

  # Given a function, returns a function that schedules the function after
  # render.
  _scheduledAfterRender: (fn) ->
    => Ember.run.schedule 'afterRender', @, fn
