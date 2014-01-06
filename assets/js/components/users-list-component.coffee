# Actions: goToRoom
App.UsersListComponent = Ember.Component.extend
  classNames: ['users-list-component']

  # Bind this to the list of users.
  users: null

  allUsers: null

  sortedUsers: null

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
    @setProperties
      prevStatusByGuid: {}
      prevClientTypeByGuid: {}
      animationQueue: []

  didInsertElement: ->
    @insertRows(@get('allUsers'))

  willDestroyElement: ->
    # TODO: remove all observers.  We never actually destroy this element
    # currently.

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
    # TODO: use a document fragment and insert once at the end.
    $e = @$('.room-members')
    users.forEach (room) =>
      @insertUserRow(room, $e)

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
    @updateStatus(room, $avatar) # Update immediately.
    room.addObserver('clientType', @, 'clientTypeDidChange')
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
    nameObserver() # Trigger immediately.
    $name.appendTo(infoCell)

    # Add a naturally breaking space between name and idle duration.
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
    shouldDisplayIdleDurationObserver = =>
      if room.get('shouldDisplayIdleDuration')
        # Only observe the idle duration when we're actually showing it.
        mostRecentIdleDurationObserver() # Trigger immediately.
        room.addObserver('mostRecentIdleDuration', mostRecentIdleDurationObserver)
        $idle.removeClass('hidden')
      else
        $idle.addClass('hidden')
        room.removeObserver('mostRecentIdleDuration', mostRecentIdleDurationObserver)
    room.addObserver('shouldDisplayIdleDuration', shouldDisplayIdleDurationObserver)
    shouldDisplayIdleDurationObserver() # Trigger immediately.
    $idle.appendTo(infoCell)

    # {{#if user.statusText}}
    #   <div class='status-text'>{{user.statusText}}</div>
    # {{/if}}
    status = document.createElement('div')
    $status = $(status)
    $status.addClass('status-text')
    room.addObserver('statusText', @, 'statusTextDidChange')
    @updateStatusText(room, $status) # Update immediately.
    $status.appendTo(infoCell)

    # <div class='clearfix'></div>
    clearfix = document.createElement('div')
    $clearfix = $(clearfix)
    $clearfix.addClass('clearfix')
    $clearfix.appendTo(a)

  statusDidChange: (room) ->
    @updateStatus(room, @$("[data-room-guid='#{Ember.guidFor(room)}'] .small-avatar"))

  updateStatus: (room, $avatar) ->
    prevStatusByGuid = @get('prevStatusByGuid')
    if room.get('hasStatusIcon')
      status = room.get('status')
    if prevStatusByGuid[Ember.guidFor(room)] != status
      $avatar.removeClass(prevStatusByGuid[Ember.guidFor(room)])
    $avatar.addClass(status)
    prevStatusByGuid[Ember.guidFor(room)] = status

  clientTypeDidChange: (room) ->
    @updateClientType(room, @$("[data-room-guid='#{Ember.guidFor(room)}'] .small-avatar"))

  updateClientType: (room, $avatar) ->
    prevClientTypeByGuid = @get('prevClientTypeByGuid')
    if room.get('hasStatusIcon')
      clientType = room.get('clientType')
    if prevClientTypeByGuid[Ember.guidFor(room)] != clientType
      $avatar.removeClass(prevClientTypeByGuid[Ember.guidFor(room)])
    $avatar.addClass(clientType)
    prevClientTypeByGuid[Ember.guidFor(room)] = clientType

  statusTextDidChange: (room) ->
    @updateStatusText(room, @$("[data-room-guid='#{Ember.guidFor(room)}'] .status-text"))

  updateStatusText: (room, $e) ->
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
