App.RoomsRoomController = Ember.ObjectController.extend

  actions:

    sendMessage: ->
      text = @get('text')
      return if Ember.isEmpty(text)

      groupId = @get('model.id')
      msg = App.Message.create
        groupId: groupId
        text: text
      App.Message.sendNewMessage(msg)
      .then (msg) =>
        # if msg instanceof App.Message
          # Message was created successfully.

      @set('text', '')
      @get('model.messages').pushObject(msg)

      return undefined
