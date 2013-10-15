App.User = Ember.Object.extend()

App.User.reopenClass

  loadRaw: (json) ->
    App.User.create
      id: if json.id? then "#{json.id}" else null
      name: json.name
      status: json.status
      statusText: json.status_text
