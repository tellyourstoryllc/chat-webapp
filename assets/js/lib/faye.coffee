App.Faye = Ember.Object.extend()

App.Faye.reopenClass

  createClient: ->
    fayeClient = new Faye.Client("#{AppConfig.fayeProtocolAndHost}/faye")

    # Authentication
    clientAuth =
      outgoing: (message, callback) ->
        # Add ext field if it's not present
        message.ext = {} if ! message.ext

        # Set the auth token
        message.ext.token = App.get('token')

        # Carry on and send the message to the server
        callback(message)

    debugLogging =
      outgoing: (message, callback) ->
        Ember.Logger.log "faye outgoing", new Date(), message if App.get('useDebugLogging')
        callback(message)

      incoming: (message, callback) ->
        Ember.Logger.log "faye incoming", new Date(), message if App.get('useDebugLogging')
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

    listenForConnectHeartbeat =
      timer: null

      incoming: (message, callback) ->
        if message.channel == Faye.Channel.CONNECT && message.successful
          App.set('isHeartbeatActive', true)
          if @timer?
            Ember.run.cancel @timer
          @timer = Ember.run.later @, 'heartbeatInactive', 60000
        callback(message)

      heartbeatInactive: ->
        @timer = null
        App.set('isHeartbeatActive', false)

    implementSaneConnectEvent =
      incoming: (message, callback) ->
        if message.channel == Faye.Channel.HANDSHAKE && message.successful
          fayeClient.trigger('app:connect')
        callback(message)

    fayeClient.addExtension(clientAuth)
    fayeClient.addExtension(debugLogging)
    fayeClient.addExtension(moveExtData)
    fayeClient.addExtension(listenForConnectHeartbeat)
    fayeClient.addExtension(implementSaneConnectEvent)

    fayeClient
