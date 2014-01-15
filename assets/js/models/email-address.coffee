#= require base-model

App.EmailAddress = App.BaseModel.extend App.LockableApiModelMixin

App.EmailAddress.reopenClass

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  propertiesFromRawAttrs: (json) ->
    id: App.BaseModel.coerceId(json.id)
    email: json.email
    isPrimary: json.is_primary

  didCreateRecord: (instance, attrs) ->
    hadId = instance.get('id')?
    # Update the instance.
    props = @propertiesFromRawAttrs(attrs)
    # Update state.
    props.isLoaded = true
    props.isSaving = false
    instance.setProperties(props)

    if ! hadId && instance.get('id')?
      # Save to our identity map.
      @_all.pushObject(instance)
      @_allById[instance.get('id')] = instance

  loadAll: ->
    @fetchAll().then (json) =>
      if ! json? || json.error?
        throw json
      App.loadAll(json)
    .fail App.rejectionHandler

  fetchAll: ->
    App.get('api').ajax('/email_addresses', 'GET', {})
