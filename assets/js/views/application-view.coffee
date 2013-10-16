App.ApplicationView = Ember.View.extend

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'focus', 'blur')

  didInsertElement: ->
    $(window).focus @focus
    $(window).blur @blur

  focus: ->
    Ember.run @, ->
      App.set('hasFocus', true)

  blur: ->
    Ember.run @, ->
      App.set('hasFocus', false)
