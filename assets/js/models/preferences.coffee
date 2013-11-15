#= require base-model

App.Preferences = App.BaseModel.extend()



App.Preferences.reopenClass

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  propertiesFromRawAttrs: (json) ->
    props =
      id: @coerceId(json.id)
      serverMentionEmail: json.server_mention_email
      serverOneToOneEmail: json.server_one_to_one_email

    # Parse client preferences as JSON.
    clientWebProps = if json.client_web? then JSON.parse(json.client_web) else null
    # Don't overwrite the nested object if one wasn't given.
    props.clientWeb = Ember.Object.create(clientWebProps) if clientWebProps?

    props
