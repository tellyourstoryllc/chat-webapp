App.MobilePromptController = Ember.Controller.extend

  room: (->
    # This is the room from the invite_token if there is one.
    App.get('continueToRoomWhenReady')
  ).property('App.continueToRoomWhenReady')

  joinCode: Ember.computed.any('room.joinCode', 'room.id')
