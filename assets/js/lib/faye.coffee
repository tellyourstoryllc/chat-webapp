App.Faye = Ember.Object.extend()

App.Faye.reopenClass

  createClient: ->
    fayeClient = new Faye.Client("http://#{AppConfig.fayeHost}/faye")

    # Authentication
    clientAuth =
      outgoing: (message, callback) ->
        # Add ext field if it's not present
        message.ext = {} if ! message.ext

        # Set the auth token
        message.ext.token = App.get('token')

        # Carry on and send the message to the server
        Ember.Logger.log "faye outgoing", message
        callback(message)

      incoming: (message, callback) ->
        Ember.Logger.log "faye incoming", message
        callback(message)

    # This extension captures messages being sent and tracks their Faye ID so
    # they can be deduped once the response is received.
    messagesByFayeId = {}
    sendingMessages =
      outgoing: (message, callback) ->
        # For sending messages, capture Faye's client ID.
        if /\/groups\/[^\/]+\/messages/.test(message.channel)
          instance = message.data.messageInstance
          delete message.data.messageInstance
          messagesByFayeId[message.id] = instance

        callback(message)

      incoming: (message, callback) ->
        if /\/groups\/[^\/]+\/messages/.test(message.channel)
          instance = messagesByFayeId[message.id]
          if instance? && message.data?
            App.Message.didCreateRecord(instance, message.data)
            # We're done with this instance.
            delete messagesByFayeId[message.id]
            # Since we already know about this message, don't call callback.
            return

        callback(message)

    fayeClient.addExtension(clientAuth)
    fayeClient.addExtension(sendingMessages)

    fayeClient
