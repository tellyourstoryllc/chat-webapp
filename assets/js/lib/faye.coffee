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
        Ember.Logger.log "faye outgoing", new Date(), message
        callback(message)

      incoming: (message, callback) ->
        Ember.Logger.log "faye incoming", new Date(), message
        callback(message)

    # Allow application to specify metadata in the `ext` property of the
    # payload.  We move it to the faye message `ext` here.
    moveExtData =
      outgoing: (message, callback) ->
        if message?.data?.ext
          message.ext ?= {}
          _.extend message.ext, message.data.ext
          delete message.data.ext
        callback(message)

    implementSaneConnectEvent =
      incoming: (message, callback) ->
        if message.channel == Faye.Channel.HANDSHAKE && message.successful
          fayeClient.trigger('app:connect')
        callback(message)

    fayeClient.addExtension(clientAuth)
    fayeClient.addExtension(moveExtData)
    fayeClient.addExtension(implementSaneConnectEvent)

    fayeClient
