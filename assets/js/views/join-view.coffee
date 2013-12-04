App.JoinView = Ember.View.extend

  didInsertElement: ->
    # Add class so that we keep the navbar full width.
    $('body').addClass 'join-page'

  willDestroyElement: ->
    $('body').removeClass 'join-page'
