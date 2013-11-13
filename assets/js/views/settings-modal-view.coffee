App.SettingsModalView = Ember.View.extend

  click: (event) ->
    # When someone clicks on the overlay, hide the modal.
    if $(event.target).hasClass('page-overlay')
      @get('controller').send('hide')
