#= require ../base-controller-mixin

App.RoomsRoomController = Ember.ObjectController.extend App.BaseControllerMixin,

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

      @resetNewMessage()
      @get('model.messages').pushObject(msg)

      return undefined
