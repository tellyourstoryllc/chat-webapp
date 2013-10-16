App.Faye = Ember.Object.extend()

App.Faye.reopenClass

  createClient: ->
    fayeClient = new Faye.Client("http://ec2-54-214-231-83.us-west-2.compute.amazonaws.com:8080/faye")

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

    fayeClient.addExtension(clientAuth)

    fayeClient
