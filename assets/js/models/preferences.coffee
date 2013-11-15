#= require base-model

App.Preferences = App.BaseModel.extend()



App.Preferences.reopenClass

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  propertiesFromRawAttrs: (json) ->
    clientWebProps = if json.client_web? then JSON.parse(json.client_web) else {}

    id: @coerceId(json.id)
    clientWeb: Ember.Object.create(clientWebProps)
    serverMentionEmail: json.server_mention_email
    serverOneToOneEmail: json.server_one_to_one_email
