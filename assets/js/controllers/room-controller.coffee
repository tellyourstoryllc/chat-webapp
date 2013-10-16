App.RoomController = Ember.ObjectController.extend

  roomChanged: (->
    @resetMessageSubscription()
  ).observes('model')

  cancelMessageSubscription: ->
    @get('subscription')?.cancel()
    @set('subscription', null)

  resetMessageSubscription: ->
    # If we have an old subscription, stop listening.
    @cancelMessageSubscription()

    client = App.get('fayeClient')
    groupId = @get('model.id')
    if ! groupId?
      Ember.Logger.warn "I can't subscribe to messages without a group ID."
      return

    subscription = client.subscribe "/groups/#{groupId}/messages", (json) ->
      Ember.Logger.log "received packet", json
      if ! json?.error?
        Ember.Logger.log "received message", json
        # TODO
    @set('subscription', subscription)

  actions:

    sendMessage: ->
      text = @get('text')
      return if Ember.isEmpty(text)

      @set('isSending', true)
      groupId = @get('model.id')
      msg = App.Message.create
        groupId: groupId
        text: text
      App.Message.sendNewMessage(msg)
      .then (msg) =>
        @set('isSending', false)
        # if msg instanceof App.Message
          # Message was created successfully.
      , (e) =>
        @set('isSending', false)
        throw e

      @set('text', '')
      @get('model.messages').pushObject(msg)

      return undefined
