App.SettingsDialogComponent = Ember.Component.extend App.BaseControllerMixin,
  classNames: ['modal', 'settings-dialog']

  isEditingName: false
  newName: ''

  isEditingEmail: false
  isSendingEmail: false
  newEmail: ''
  emailErrorMessage: null

  isSendingAvatar: false
  isSendingOneToOneWallpaper: false

  selectedTab: 'general'

  preferences: (->
    App.get('preferences')
  ).property('App.preferences')

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'onBodyKeyDown', 'fileChange', 'onOneToOneWallpaperFileChange')

  didInsertElement: ->
    $('body').on 'keydown', @onBodyKeyDown
    @$('.avatar-file-input').on 'change', @fileChange
    @$('.one-to-one-wallpaper-file-input').on 'change', @onOneToOneWallpaperFileChange
    @_updateUi()

  willDestroyElement: ->
    $('body').off 'keydown', @onBodyKeyDown
    @$('.avatar-file-input').off 'change', @fileChange
    @$('.one-to-one-wallpaper-file-input').off 'change', @onOneToOneWallpaperFileChange

  isShowingGeneralTab: Ember.computed.equal('selectedTab', 'general')
  isShowingAccountTab: Ember.computed.equal('selectedTab', 'account')

  selectedTabChanged: (->
    @setProperties
      isEditingName: false
      isEditingEmail: false
    @_updateUi()
  ).observes('selectedTab')

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
          else
            # Close the dialog.
            @send('hideDialog')

  isHiddenChanged: (->
    if @get('isHidden')
      @$().removeClass('expand-in')
    else
      @$().addClass('expand-in')
  ).observes('isHidden')

  fileChange: (event) ->
    Ember.run @, ->
      file = event.target.files?[0]
      return unless file?

      @updateAvatar(file)

  updateAvatar: (file) ->
    api = App.get('api')
    formData = new FormData()
    formData.append(k, v) for k,v of api.defaultParams()
    formData.append('avatar_image_file', file)
    @set('isSendingAvatar', true)
    api.ajax(api.buildURL('/users/update'), 'POST',
      data: formData
      processData: false
      contentType: false
    )
    .always =>
      @set('isSendingAvatar', false)

  onOneToOneWallpaperFileChange: (event) ->
    Ember.run @, ->
      file = event.target.files?[0]
      return unless file?

      @updateOneToOneWallpaper(file)

  # Persists the file to the API.  Use `null` file to remove it.
  updateOneToOneWallpaper: (file) ->
    return if @get('isSendingOneToOneWallpaper')
    api = App.get('api')
    formData = new FormData()
    formData.append(k, v) for k,v of api.defaultParams()
    formData.append('one_to_one_wallpaper_image_file', file)
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

  clientWebPreferencesDidChange: (->
    # When the global preferences change, sync the UI.
    @_updateUi()
  ).observes('preferences.clientWeb.playSoundOnMessageReceive',
             'preferences.clientWeb.showNotificationOnMessageReceive',
             'preferences.clientWeb.playSoundOnMention',
             'preferences.clientWeb.showNotificationOnMention',
             'preferences.clientWeb.showJoinLeaveMessages',
             'preferences.clientWeb.showAvatars',
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
      @$('.play-sound-on-message-receive-checkbox').prop('checked', clientPrefs.get('playSoundOnMessageReceive'))
      @$('.show-notification-on-message-receive-checkbox').prop('checked', clientPrefs.get('showNotificationOnMessageReceive'))
      @$('.play-sound-on-mention-checkbox').prop('checked', clientPrefs.get('playSoundOnMention'))
      @$('.show-notification-on-mention-checkbox').prop('checked', clientPrefs.get('showNotificationOnMention'))
      @$('.notification-volume').val(clientPrefs.get('notificationVolume'))

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

    editEmail: ->
      @set('isEditingEmail', true)
      @set('newEmail', App.get('currentUser.account.email'))
      Ember.run.schedule 'afterRender', @, ->
        @$('.email-input').textrange('set') # Select all.
      return undefined

    cancelEditingEmail: ->
      @set('isEditingEmail', false)
      @set('emailErrorMessage', null)
      return undefined

    saveEmail: ->
      newEmail = @get('newEmail')
      return if Ember.isEmpty(newEmail)

      @set('emailErrorMessage', null)
      user = App.get('currentUser')
      account = user.get('account')
      oldEmail = account.get('email')
      if account.isPropertyLocked('email')
        Ember.Logger.log "Can't change account email when it's locked."
        return

      # If name didn't change, we're done.
      if oldEmail == newEmail
        @set('isEditingEmail', false)
        return

      @set('isSendingEmail', true)
      data =
        email: newEmail
        password: @$('.password-input').val()
      url = App.get('api').buildURL('/accounts/update')
      account.withLockedPropertyTransaction url, 'POST', { data: data }, 'email', =>
        account.set('email', newEmail)
      , (xhrOrJson) =>
        account.set('email', oldEmail)
        if xhrOrJson.status == 401
          @set('emailErrorMessage', "Invalid password.")
        else
          @set('emailErrorMessage', "Unknown error occurred.  Please try again.")
      .then ([isSuccessful, json]) =>
        @set('isSendingEmail', false)
        @set('isEditingEmail', false) if isSuccessful

      return undefined

    changeVolumePreference: _.debounce (key) ->
      # This gets triggered as you slide, so need to debounce.
      @send('changeClientPreference', key)
      return undefined
    , 200

    changeClientPreference: (key) ->
      clientPrefs = @get('preferences.clientWeb')
      clientPrefs.setProperties
        showJoinLeaveMessages: @$('#show-join-leave-messages-checkbox').is(':checked')
        showAvatars: @$('#show-avatars-checkbox').is(':checked')
        playSoundOnMessageReceive: @$('.play-sound-on-message-receive-checkbox').is(':checked')
        showNotificationOnMessageReceive: @$('.show-notification-on-message-receive-checkbox').is(':checked')
        playSoundOnMention: @$('.play-sound-on-mention-checkbox').is(':checked')
        showNotificationOnMention: @$('.show-notification-on-mention-checkbox').is(':checked')
        notificationVolume: parseInt(@$('.notification-volume').val())
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
