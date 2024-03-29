App.SettingsDialogComponent = Ember.Component.extend App.BaseControllerMixin,
  classNames: ['modal', 'settings-dialog']

  isEditingName: false
  newName: ''

  isEditingEmail: false
  isSendingEmail: false
  newEmail: ''
  emailErrorMessage: null

  isLoadingEmailAddresses: false
  emailAddresses: null
  emailAddressesFetchedAt: null
  isRemovingEmailAddress: false

  isEditingPassword: false
  isSendingPassword: false
  newPassword: ''
  confirmPassword: ''
  passwordErrorMessage: null

  isSendingAvatar: false
  isSendingOneToOneWallpaper: false

  selectedTab: 'general'

  preferences: (->
    App.get('preferences')
  ).property('App.preferences')

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onBodyKeyDown', 'onAvatarFileChange', 'onOneToOneWallpaperFileChange')
    @setProperties
      emailAddresses: []

  didInsertElement: ->
    $('body').on 'keydown', @onBodyKeyDown
    Ember.run.schedule 'afterRender', @, ->
      @$().on 'change', '.avatar-file-input', @onAvatarFileChange
      @$().on 'change', '.one-to-one-wallpaper-file-input', @onOneToOneWallpaperFileChange
    @_updateUi()

  willDestroyElement: ->
    $('body').off 'keydown', @onBodyKeyDown
    @$().off 'change', '.avatar-file-input', @onAvatarFileChange
    @$().off 'change', '.one-to-one-wallpaper-file-input', @onOneToOneWallpaperFileChange

  isShowingGeneralTab: Ember.computed.equal('selectedTab', 'general')
  isShowingNotificationsTab: Ember.computed.equal('selectedTab', 'notifications')
  isShowingAccountTab: Ember.computed.equal('selectedTab', 'account')

  selectedTabChanged: (->
    # Cancel editing.
    @setProperties
      isEditingName: false
      isEditingPassword: false
    @send('cancelEditingEmail')

    @ensureEmailAddressesLoaded() if @get('selectedTab') == 'account'

    @_updateUi()
  ).observes('selectedTab')

  ensureEmailAddressesLoaded: ->
    emailAddressesFetchedAt = @get('emailAddressesFetchedAt')
    # Cache email addresses for a minute.
    if ! emailAddressesFetchedAt? || (new Date().getTime() - emailAddressesFetchedAt.getTime()) / 1000 > 60
      @set('isLoadingEmailAddresses', true)
      App.Email.loadAll()
      .always =>
        @set('isLoadingEmailAddresses', false)
      .then =>
        @setProperties
          # We modify this array, so make sure it's a copy.
          emailAddresses: App.Email.all().copy()
          emailAddressesFetchedAt: new Date()
      , (e) =>
        # Never cache bad results.
        @set('emailAddressesFetchedAt', null)

  onBodyKeyDown: (event) ->
    Ember.run @, ->
      # No key modifiers.
      if ! (event.ctrlKey || event.shiftKey || event.metaKey || event.altKey)
        if event.which == 27 # Escape.
          # Stop editing.
          if @get('isEditingName')
            @send('cancelEditingName')
          else if @get('isEditingEmail')
            @send('cancelEditingEmail')
          else if @get('isEditingPassword')
            @send('cancelEditingPassword')
          else
            # Close the dialog.
            @send('hideDialog')

  isHiddenChanged: (->
    if @get('isHidden')
      @$().removeClass('expand-in')
      # After the transition completes, if the dialog is still hidden, clear
      # cache of email addresses.
      Ember.run.later @, ->
        @set('emailAddressesFetchedAt', null) if @get('isHidden')
      , 1000
    else
      @$().addClass('expand-in')
      # When showing the dialog, make sure email addresses are loaded and fresh.
      @ensureEmailAddressesLoaded()
  ).observes('isHidden')

  isLinkedToFacebook: (->
    ! Ember.isEmpty(App.get('currentUser.account.facebookId'))
  ).property('App.currentUser.account.facebookId')

  onAvatarFileChange: (event) ->
    Ember.run @, ->
      file = event.target.files?[0]
      return unless file?

      @updateAvatar(file)
      return undefined

  updateAvatar: (file) ->
    api = App.get('api')
    formData = new FormData()
    formData.append(k, v) for k,v of api.defaultParams()
    formData.append('avatar_image_file', file ? '')
    @set('isSendingAvatar', true)
    api.ajax(api.buildURL('/users/update'), 'POST',
      data: formData
      processData: false
      contentType: false
    )
    .always =>
      @set('isSendingAvatar', false)
    .catch App.rejectionHandler

    # Clear out the file input so that selecting the same file again triggers a
    # change event.
    @$('.avatar-file-input').val('')

  onOneToOneWallpaperFileChange: (event) ->
    Ember.run @, ->
      file = event.target.files?[0]
      return unless file?

      @updateOneToOneWallpaper(file)
      return undefined

  # Persists the file to the API.  Use `null` file to remove it.
  updateOneToOneWallpaper: (file) ->
    return if @get('isSendingOneToOneWallpaper')
    api = App.get('api')
    formData = new FormData()
    formData.append(k, v) for k,v of api.defaultParams()
    # Safari and WebUI send the string "null" so make sure to use empty string.
    formData.append('one_to_one_wallpaper_image_file', file ? '')
    @set('isSendingOneToOneWallpaper', true)
    api.ajax(api.buildURL('/accounts/update'), 'POST',
      data: formData
      processData: false
      contentType: false
    )
    .always =>
      @set('isSendingOneToOneWallpaper', false)
    .then (json) =>
      App.loadAll(json)
    .catch App.rejectionHandler

    # Clear out the file input so that selecting the same file again triggers a
    # change event.
    @$('.one-to-one-wallpaper-file-input').val('')

  clientWebPreferencesDidChange: (->
    # When the global preferences change, sync the UI.
    @_updateUi()
  ).observes('preferences.clientWeb.playSoundOnMessageReceive',
             'preferences.clientWeb.showNotificationOnMessageReceive',
             'preferences.clientWeb.bounceDockOnMessageReceive',
             'preferences.clientWeb.playSoundOnOneToOneMessageReceive',
             'preferences.clientWeb.showNotificationOnOneToOneMessageReceive',
             'preferences.clientWeb.bounceDockOnOneToOneMessageReceive',
             'preferences.clientWeb.playSoundOnMention',
             'preferences.clientWeb.showNotificationOnMention',
             'preferences.clientWeb.bounceDockOnMention',
             'preferences.clientWeb.showJoinLeaveMessages',
             'preferences.clientWeb.showAvatars',
             'preferences.clientWeb.showWallpaper',
             'preferences.clientWeb.notificationVolume')

  serverPreferencesDidChange: (->
    # When the global preferences change, sync the UI.
    @_updateUi()
  ).observes('preferences.serverMentionEmail',
             'preferences.serverOneToOneEmail')

  preferencesChanged: (->
    @_updateUi()
  ).observes('preferences', 'preferences.clientWeb')

  _updateUi: ->
    Ember.run.schedule 'afterRender', @, ->
      prefs = @get('preferences')
      return unless prefs?
      @$('.server-mention-email-checkbox').prop('checked', prefs.get('serverMentionEmail'))
      @$('.server-one-to-one-email-checkbox').prop('checked', prefs.get('serverOneToOneEmail'))
      clientPrefs = prefs.get('clientWeb')
      return unless clientPrefs?
      @$('#show-join-leave-messages-checkbox').prop('checked', clientPrefs.get('showJoinLeaveMessages'))
      @$('#show-avatars-checkbox').prop('checked', clientPrefs.get('showAvatars'))
      @$('#show-wallpaper-checkbox').prop('checked', clientPrefs.get('showWallpaper'))
      @$('.play-sound-on-message-receive-checkbox').prop('checked', clientPrefs.get('playSoundOnMessageReceive'))
      @$('.show-notification-on-message-receive-checkbox').prop('checked', clientPrefs.get('showNotificationOnMessageReceive'))
      @$('.bounce-dock-on-message-receive-checkbox').prop('checked', clientPrefs.get('bounceDockOnMessageReceive'))
      @$('.play-sound-on-one-to-one-message-receive-checkbox').prop('checked', clientPrefs.get('playSoundOnOneToOneMessageReceive'))
      @$('.show-notification-on-one-to-one-message-receive-checkbox').prop('checked', clientPrefs.get('showNotificationOnOneToOneMessageReceive'))
      @$('.bounce-dock-on-one-to-one-message-receive-checkbox').prop('checked', clientPrefs.get('bounceDockOnOneToOneMessageReceive'))
      @$('.play-sound-on-mention-checkbox').prop('checked', clientPrefs.get('playSoundOnMention'))
      @$('.show-notification-on-mention-checkbox').prop('checked', clientPrefs.get('showNotificationOnMention'))
      @$('.bounce-dock-on-mention-checkbox').prop('checked', clientPrefs.get('bounceDockOnMention'))
      @$('.notification-volume').val(clientPrefs.get('notificationVolume'))

  isAddingNewEmailAddress: (->
    emailAddress = @get('editingEmailAddress')
    emailAddress? && ! emailAddress.get('id')?
  ).property('editingEmailAddress.id')

  canRemoveEmailAddress: Ember.computed.gt('emailAddresses.length', 1)

  actions:

    showTab: (tabName) ->
      @set('selectedTab', tabName)
      return undefined

    chooseAvatarFile: ->
      @$('.avatar-file-input').trigger('click')
      return undefined

    chooseOneToOneWallpaperFile: ->
      @$('.one-to-one-wallpaper-file-input').trigger('click')
      return undefined

    removeOneToOneWallpaper: ->
      @updateOneToOneWallpaper(null)
      return undefined

    hideDialog: ->
      @get('targetObject').send('hide')
      return undefined

    editName: ->
      @set('isEditingName', true)
      @set('newName', App.get('currentUser.name'))
      Ember.run.schedule 'afterRender', @, ->
        @$('.name-input').textrange('set') # Select all.
      return undefined

    cancelEditingName: ->
      @set('isEditingName', false)
      return undefined

    saveName: ->
      newName = @get('newName')
      return if Ember.isEmpty(newName)

      user = App.get('currentUser')
      oldName = user.get('name')
      if user.isPropertyLocked('name')
        Ember.Logger.log "Can't change user name when it's locked."
        return

      @set('isEditingName', false)
      # If name didn't change, we're done.
      return if oldName == newName

      data =
        name: newName
      url = App.get('api').buildURL('/users/update')
      user.withLockedPropertyTransaction url, 'POST', { data: data }, 'name', =>
        user.set('name', newName)
      , =>
        user.set('name', oldName)

      return undefined

    editEmail: (emailAddress) ->
      @set('isEditingEmail', true)
      @set('editingEmailAddress', emailAddress)
      @set('newEmail', emailAddress.get('email'))
      Ember.run.schedule 'afterRender', @, ->
        @$('.email-input').textrange('set') # Select all.
      return undefined

    cancelEditingEmail: ->
      # Remove unsaved email address from the list.
      emailAddress = @get('editingEmailAddress')
      if emailAddress? && ! emailAddress.get('id')?
        @get('emailAddresses').removeObject(emailAddress)

      @set('isEditingEmail', false)
      @set('editingEmailAddress', null)
      @set('emailErrorMessage', null)
      return undefined

    saveEmail: ->
      newEmail = @get('newEmail')
      return if Ember.isEmpty(newEmail)

      @set('emailErrorMessage', null)
      user = App.get('currentUser')
      emailAddress = @get('editingEmailAddress')
      oldEmail = emailAddress?.get('email')
      if emailAddress? && emailAddress.isPropertyLocked('email')
        Ember.Logger.log "Can't change email when it's locked."
        return

      # If no change, we're done.
      if oldEmail == newEmail
        @set('isEditingEmail', false)
        @set('editingEmailAddress', null)
        return

      @set('isSendingEmail', true)
      data =
        email: newEmail
      if emailAddress?.get('id')?
        url = App.get('api').buildURL("/emails/#{emailAddress.get('id')}/update")
      else
        url = App.get('api').buildURL('/emails/create')
      emailAddress.withLockedPropertyTransaction url, 'POST', { data: data }, 'email', =>
        emailAddress.set('email', newEmail)
      , (xhrOrJson) =>
        emailAddress.set('email', oldEmail)
        @set('emailErrorMessage', App.userMessageFromError(xhrOrJson, "Unknown error occurred.  Please try again."))
      .then ([isSuccessful, json]) =>
        @set('isSendingEmail', false)
        if isSuccessful
          @set('isEditingEmail', false)
          @set('editingEmailAddress', null)
          # Save to our store for later.
          emailJson = Ember.makeArray(json).find (o) -> o.object_type == 'email'
          App.Email.didCreateRecord(emailAddress, emailJson) if emailJson?

      return undefined

    addEmailAddress: ->
      @send('cancelEditingEmail')
      emailAddress = App.Email.create()
      @get('emailAddresses').pushObject(emailAddress)
      @send('editEmail', emailAddress)
      return undefined

    removeEmail: (emailAddress) ->
      return if @get('isRemovingEmailAddress')
      if ! @get('canRemoveEmailAddress')
        alert "You must add another email address before removing your last one."
        return
      if ! emailAddress.get('id')?
        Ember.Logger.error "email address can't be destroyed since it has no id", emailAddress
        return

      @set('isRemovingEmailAddress', true)
      emailAddresses = @get('emailAddresses')
      # Hide from UI immediately.
      @$(".editable-display[data-email-id='#{emailAddress.get('id')}']").addClass('hidden')

      api = App.get('api')
      api.ajax(api.buildURL("/emails/#{emailAddress.get('id')}/destroy"), 'POST', {})
      .always =>
        @set('isRemovingEmailAddress', false)
      .then (json) =>
        if ! json? || json.error?
          throw json
        emailAddresses.removeObject(emailAddress)
        App.Email.discardRecords(emailAddress)
      .catch (xhrOrError) =>
        # Revert changes.
        @$(".editable-display[data-email-id='#{emailAddress.get('id')}']").removeClass('hidden')
      return undefined

    editPassword: ->
      @set('isEditingPassword', true)
      @set('newPassword', '')
      @set('confirmPassword', '')
      Ember.run.schedule 'afterRender', @, ->
        @$('.current-password-input').focus()
      return undefined

    cancelEditingPassword: ->
      @set('isEditingPassword', false)
      @set('passwordErrorMessage', null)
      return undefined

    savePassword: ->
      newPassword = @get('newPassword') ? ''
      confirmPassword = @get('confirmPassword') ? ''

      minPasswordLength = App.Account.minPasswordLength()
      if newPassword.length < minPasswordLength
        @set('passwordErrorMessage', "New password must be at least #{minPasswordLength} characters.")
        return

      if newPassword != confirmPassword
        @set('passwordErrorMessage', "Passwords must match.")
        return

      @set('passwordErrorMessage', null)

      @set('isSendingPassword', true)
      data =
        password: @$('.current-password-input').val()
        new_password: newPassword
      url = App.get('api').buildURL('/accounts/update')
      App.get('api').ajax(url, 'POST', data: data, skipLogOutOnInvalidTokenFilter: true)
      .always =>
        @set('isSendingPassword', false)
      .then (json) =>
        if ! json? || json.error?
          throw json
        # Success.
        @set('isEditingPassword', false)

        # Should return user and account.
        json = Ember.makeArray(json)
        # Use the updated auth token.
        userJson = json.find (obj) -> obj.object_type == 'user'
        token = userJson?.token
        if token?
          App.useNewAuthToken(token)
      .catch (xhrOrJson) =>
        Ember.Logger.error xhrOrJson
        if xhrOrJson.status == 401
          @set('passwordErrorMessage', "Invalid current password.")
        else
          @set('passwordErrorMessage', "Unknown error occurred.  Please try again.")

      return undefined

    changeVolumePreference: _.debounce (key) ->
      # This gets triggered as you slide, so need to debounce.
      @send('changeNotificationClientPreference', key)

      # Play the sound if the user is changing the volume.
      audio = $('.receive-message-sound').get(0)
      if audio?
        audio.currentTime = 0 if audio.currentTime > 0
        audio.play()

      return undefined
    , 200

    changeGeneralClientPreference: (key) ->
      clientPrefs = @get('preferences.clientWeb')
      clientPrefs.setProperties
        showJoinLeaveMessages: @$('#show-join-leave-messages-checkbox').is(':checked')
        showAvatars: @$('#show-avatars-checkbox').is(':checked')
        showWallpaper: @$('#show-wallpaper-checkbox').is(':checked')
      # Save to localStorage.
      window.localStorage.setItem(key, clientPrefs.get(key))
      # Save to server.
      data =
        client_web: JSON.stringify(clientPrefs)
      App.get('api').updatePreferences(data)
      return undefined

    changeNotificationClientPreference: (key) ->
      clientPrefs = @get('preferences.clientWeb')
      clientPrefs.setProperties
        playSoundOnMessageReceive: @$('.play-sound-on-message-receive-checkbox').is(':checked')
        showNotificationOnMessageReceive: @$('.show-notification-on-message-receive-checkbox').is(':checked')
        playSoundOnOneToOneMessageReceive: @$('.play-sound-on-one-to-one-message-receive-checkbox').is(':checked')
        showNotificationOnOneToOneMessageReceive: @$('.show-notification-on-one-to-one-message-receive-checkbox').is(':checked')
        playSoundOnMention: @$('.play-sound-on-mention-checkbox').is(':checked')
        showNotificationOnMention: @$('.show-notification-on-mention-checkbox').is(':checked')
        notificationVolume: parseInt(@$('.notification-volume').val())
      if App.get('isMacGap')
        clientPrefs.setProperties
          bounceDockOnMessageReceive: @$('.bounce-dock-on-message-receive-checkbox').is(':checked')
          bounceDockOnOneToOneMessageReceive: @$('.bounce-dock-on-one-to-one-message-receive-checkbox').is(':checked')
          bounceDockOnMention: @$('.bounce-dock-on-mention-checkbox').is(':checked')
      # Save to localStorage.
      window.localStorage.setItem(key, clientPrefs.get(key))
      # Save to server.
      data =
        client_web: JSON.stringify(clientPrefs)
      App.get('api').updatePreferences(data)
      return undefined

    changeServerPreference: ->
      data =
        server_mention_email: @$('.server-mention-email-checkbox').is(':checked')
        server_one_to_one_email: @$('.server-one-to-one-email-checkbox').is(':checked')
      App.get('api').updatePreferences(data)
      return undefined
