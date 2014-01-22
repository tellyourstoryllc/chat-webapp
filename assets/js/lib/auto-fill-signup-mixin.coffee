App.AutoFillSignupMixin = Ember.Mixin.create

  userHasChangedName: false

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onEmailInput', 'onEmailBlur')

  didInsertElement: ->
    @_super(arguments...)
    @$('.email-input').on 'input', @onEmailInput
    @$('.email-input').on 'blur', @onEmailBlur

  willDestroyElement: ->
    @_super(arguments...)
    @$('.email-input').off 'input', @onEmailInput
    @$('.email-input').off 'blur', @onEmailBlur

  defaultName: (email) ->
    email ?= ''
    name = ''
    if (matches = /^([^@\+]+)/.exec(email))
      name = matches[1].trim()

    name

  onEmailInput: (event) ->
    Ember.run @, ->
      if ! @get('userHasChangedName')
        name = @defaultName(@$('.email-input').val())
        @set('name', name)
      return undefined

  onEmailBlur: (event) ->
    Ember.run @, ->
      if ! @get('userHasChangedName')
        name = @defaultName(@$('.email-input').val())
        @set('name', name)
      return undefined
