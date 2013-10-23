App.BaseModel = Ember.Object.extend

  isLoading: false
  isLoaded: false
  isSaving: false
  isError: false


App.BaseModel.reopenClass

  coerceId: (id) ->
    if id? then "#{id}" else null
