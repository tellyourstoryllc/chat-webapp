#= require base-model

App.Email = App.BaseModel.extend App.LockableApiModelMixin

App.Email.reopenClass

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  propertiesFromRawAttrs: (json) ->
    id: @coerceId(json.id)
    userId: @coerceId(json.user_id)
    email: json.email

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
    api = App.get('api')
    api.ajax(api.buildURL('/emails'), 'GET', {})
