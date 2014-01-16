App.SettingsEmailAddressView = Ember.View.extend
  tagName: 'tr'

  emailAddress: Ember.computed.alias('content')

  isEditingEmail: (->
    @get('emailAddress') == @get('controller.editingEmailAddress')
  ).property('emailAddress', 'controller.editingEmailAddress')

  isFirstRow: Ember.computed.equal('contentIndex', 0)

  actions:

    editEmail: ->
      # If removing and semi-transparent, don't allow editing.
      return if @get('controller.isRemovingEmailAddress')

      @get('controller').send('editEmail', @get('emailAddress'))
      Ember.run.schedule 'afterRender', @, ->
        @$('.email-input').focus().textrange('set') # Select all.
      return undefined

    cancelEditingEmail: ->
      @get('controller').send('cancelEditingEmail', @get('emailAddress'))
      return undefined
