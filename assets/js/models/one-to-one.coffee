#= require base-model
#= require conversation

App.OneToOne = App.BaseModel.extend App.Conversation, App.LockableApiModelMixin,

  name: (->
    # TODO
    null
  ).property()

  mostRecentMessagesUrl: (->
    App.get('api').buildURL("/one_to_ones/#{@get('id')}/messages")
  ).property('id')

  earlierMessagesUrl: (->
    App.get('api').buildURL("/one_to_ones/#{@get('id')}/messages")
  ).property('id')


App.OneToOne.reopenClass

  # Array of all instances.  Public access is with `all()`.
  _all: []

  # Identity map of model instances by ID.  Public access is with `lookup()`.
  _allById: {}

  propertiesFromRawAttrs: (json) ->
    id: @coerceId(json.id)
    memberIds: (json.member_ids ? []).map (id) -> @coerceId(id)

  fetchById: (id) ->
    api = App.get('api')
    data =
      limit: 100
    api.ajax(api.buildURL("/one_to_ones/#{id}"), 'GET', data: data)
