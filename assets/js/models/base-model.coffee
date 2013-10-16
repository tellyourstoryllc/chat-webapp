App.BaseModel = Ember.Object.extend

  isLoaded: false
  isSaving: false


App.BaseModel.reopenClass

  coerceId: (id) ->
    if id? then "#{id}" else null
