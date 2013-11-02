# Locking and RPC transactions for models that persist to the API.
App.LockableApiModelMixin = Ember.Mixin.create

  init: ->
    @set('_lockedProperties', [])
    @_super()

  isPropertyLocked: (properties) ->
    properties = Ember.makeArray(properties)
    lockedProps = @get('_lockedProperties')
    properties.some (prop) -> prop in lockedProps

  arePropertiesLocked: Ember.aliasMethod('isPropertyLocked')

  lockProperty: (properties) ->
    properties = Ember.makeArray(properties)
    lockedProps = @get('_lockedProperties')
    if @arePropertiesLocked(properties)
      throw new Error("You can't lock a property that's already locked; properties=#{Ember.inspect(properties)}, _lockedProperties=#{Ember.inspect(lockedProps)}")
    lockedProps.pushObjects(lockedProps)

  lockProperties: Ember.aliasMethod('lockProperty')

  unlockProperty: (properties) ->
    properties = Ember.makeArray(properties)
    lockedProps = @get('_lockedProperties')
    if ! @arePropertiesLocked(properties)
      throw new Error("You can't unlock a property that's not locked; properties=#{Ember.inspect(properties)}, _lockedProperties=#{Ember.inspect(lockedProps)}")
    lockedProps.removeObjects(lockedProps)

  unlockProperties: Ember.aliasMethod('unlockProperty')

  # Executes AJAX call, locking the affected properties, and rolling back the
  # record if it fails.  Returns an RSVP.Promise.
  #
  # Caller must specify which properties are affected.  Affected properties are
  # locked, your callback is called, and then a commit to the server is
  # attempted.  If there's a failure, `rollback()` is called whose
  # responsibility is to roll back the local model.
  withLockedPropertyTransaction: (url, httpMethod, ajaxHash, properties, callback, rollback) ->
    @lockProperties(properties)

    callback()

    # Send the update to the server.
    api = App.get('api')
    api.ajax(url, httpMethod, ajaxHash)
    .then (json) =>
      if ! json? || json.error?
        Ember.Logger.error "API error committing locked property transaction: #{json?.error.message}"
        rollback(json)
      else
        # For success, ignore the result.  Assume it worked.

      # Always unlock the properties.
      @unlockProperties(properties)
      return json

    , (xhr) =>
      rollback(xhr)
      @unlockProperties(properties)
