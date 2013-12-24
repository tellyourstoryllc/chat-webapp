App.RoomsIndexView = Ember.View.extend

  didInsertElement: ->
    $('.room-content').addClass('lobby')

  willDestroyElement: ->
    $('.room-content').removeClass('lobby')
