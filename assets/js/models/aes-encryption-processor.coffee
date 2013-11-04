App.AesEncryptionProcessor = Ember.Object.extend

  key: null

  init: ->
    @set('outgoingParams', { ks: 256 }) # Key size.

  incoming: (message, text) ->
    sjcl.decrypt(@get('key'), text)

  outgoing: (message, text) ->
    sjcl.encrypt(@get('key'), text, @get('outgoingParams'))
