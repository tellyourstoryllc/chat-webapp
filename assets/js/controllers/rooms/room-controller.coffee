#= require ../base-controller-mixin

App.RoomsRoomController = Ember.ObjectController.extend App.BaseControllerMixin,
  needs: ['rooms']

  resetNewMessage: ->
    @set('newMessageText', '')
    @set('newMessageFile', null)

  actions:

    sendMessage: ->
      text = @get('newMessageText')
      file = @get('newMessageFile')
      return if Ember.isEmpty(text) && Ember.isEmpty(file)

      groupId = @get('model.id')
      msg = App.Message.create
        userId: App.get('currentUser.id')
        groupId: groupId
        text: text
        imageFile: file
      App.Message.sendNewMessage(msg)
      .then (msg) =>
        # if msg instanceof App.Message
          # Message was created successfully.
        # else
          # TODO: set msg as errored.

      @resetNewMessage()
      @get('model.messages').pushObject(msg)

      return undefined

    showPreviousRoom: ->
      groups = @get('controllers.rooms.rooms')
      index = groups.indexOf(@get('model'))
      if index >= 0
        index--
        index = groups.length - 1 if index < 0
        @transitionToRoute('rooms.room', groups[index])
      return undefined

    showNextRoom: ->
      groups = @get('controllers.rooms.rooms')
      index = groups.indexOf(@get('model'))
      if index >= 0
        index++
        index = 0 if index >= groups.length
        @transitionToRoute('rooms.room', groups[index])
      return undefined
