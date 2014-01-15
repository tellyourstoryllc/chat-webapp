App.SettingsEmailAddressView = Ember.View.extend
  tagName: 'tr'

  emailAddress: Ember.computed.alias('content')

  isEditingEmail: (->
    @get('emailAddress') == @get('controller.editingEmailAddress')
  ).property('emailAddress', 'controller.editingEmailAddress')

  isFirstRow: Ember.computed.equal('contentIndex', 0)

  actions:

    editEmail: ->
      @get('controller').send('editEmail', @get('emailAddress'))
      Ember.run.schedule 'afterRender', @, ->
        @$('.email-input').focus().textrange('set') # Select all.
      return undefined

    cancelEditingEmail: ->
      @get('controller').send('cancelEditingEmail', @get('emailAddress'))
      return undefined

    removeEmail: ->
      Ember.Logger.error 'TODO: removeEmail', @get('emailAddress'), @get('parentView.canRemoveEmailAddress')
      return undefined
