App.IndexView = Ember.View.extend

  didInsertElement: ->
    $('body').addClass('home-page')

  willDestroyElement: ->
    $('body').removeClass('home-page')

  actions:

    submitRoomKey: ->
      console.log "TODO"
      return undefined
