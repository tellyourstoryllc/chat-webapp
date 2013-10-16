App.RoomsRoomController = Ember.ObjectController.extend

  actions:

    sendMessage: ->
      text = @get('newMessageText')
      return if Ember.isEmpty(text)

      groupId = @get('model.id')
      msg = App.Message.create
        userId: App.get('currentUser.id')
        groupId: groupId
        text: text
      App.Message.sendNewMessage(msg)
      .then (msg) =>
        # if msg instanceof App.Message
          # Message was created successfully.

      @set('newMessageText', '')
      @get('model.messages').pushObject(msg)

      return undefined
