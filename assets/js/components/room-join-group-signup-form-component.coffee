#= require signup-form-component

# Actions: signUpWithFacebook, logInWithRoom
App.RoomJoinGroupSignupFormComponent = App.SignupFormComponent.extend App.AutoFillSignupMixin,
  classNames: ['room-join-group-signup-form-component']

  showRelatedLinks: false
  showFacebookChoice: true
  shouldRequirePassword: false

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onResize')

  didInsertElement: ->
    @_super(arguments...)
    $(window).on 'resize', @onResize
    Ember.run.schedule 'afterRender', @, 'updateSize'

  onResize: _.throttle (event) ->
    Ember.run @, ->
      @updateSize()
      return undefined
  , 100, leading: false

  updateSize: ->
    $e = @$()
    width = $e.outerWidth()
    height = $e.outerHeight()
    $window = $(window)
    windowWidth = $window.width()
    windowHeight = $window.height()
    bannerHeight = if Modernizr.appleios || Modernizr.android then 50 else 0
    visibleHeight = windowHeight - bannerHeight

    $e.css
      left: Math.round((windowWidth - width) / 2)
      top: Math.round((visibleHeight - height) / 2) + bannerHeight

  userErrorMessageDidChange: (->
    Ember.run.schedule 'afterRender', @, ->
      # Run later so that it's actually inserted into the DOM and the CSS can
      # transition.
      Ember.run.later @, ->
        # Transition the error message in.
        if Ember.isEmpty(@get('errorMessage'))
          @$('.alert').removeClass('visible')
        else
          @$('.alert').addClass('visible')
      , 50
  ).observes('errorMessage')

  actions:

    logInWithRoom: ->
      @sendAction('logInWithRoom')
      return undefined
