App.BaseModel = Ember.Object.extend()

App.BaseModel.reopenClass

  coerceId: (id) ->
    if id? then "#{id}" else null
