# Actions: submitRoomKey
App.RoomKeyFormComponent = Ember.Component.extend

  roomKeyText: ''

  classNames: ['room-key-form-component']

  roomKeyTextChanged: (->
    roomKeyText = @get('roomKeyText') ? ''
    @$('.room-key-input')?.val(roomKeyText)
  ).observes('roomKeyText').on('didInsertElement')

  actions:

    submitRoomKey: ->
      @sendAction('submitRoomKey', @$('.room-key-input').val())
      return undefined
