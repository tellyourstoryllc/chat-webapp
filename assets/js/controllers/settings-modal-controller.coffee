App.SettingsModalController = Ember.Controller.extend App.BaseControllerMixin,

  isHidden: true

  actions:

    hide: ->
      @set('isHidden', true)

    show: ->
      @set('isHidden', false)
