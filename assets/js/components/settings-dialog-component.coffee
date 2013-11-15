App.SettingsDialogComponent = Ember.Component.extend App.BaseControllerMixin,
  classNames: ['modal', 'settings-dialog']

  isSendingAvatar: false

  preferences: (->
    App.get('preferences')
  ).property('App.preferences')

  init: ->
    @_super(arguments...)
    _.bindAll(@, 'fileChange')

  didInsertElement: ->
    @$('.avatar-file-input').on 'change', @fileChange
    @_updateUi()

  willDestroyElement: ->
    @$('.avatar-file-input').off 'change', @fileChange

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

  clientWebPreferencesDidChange: (->
    data =
      client_web: JSON.stringify(@get('preferences.clientWeb'))
    App.get('api').updatePreferences(data)
  ).observes('preferences.clientWeb.playSoundOnMessageReceive',
             'preferences.clientWeb.showNotificationOnMessageReceive',
             'preferences.clientWeb.playSoundOnMention',
             'preferences.clientWeb.showNotificationOnMention',
             'preferences.clientWeb.showJoinLeaveMessages',
             'preferences.clientWeb.showAvatars')

  serverPreferencesDidChange: (->
    # When the global preferences change, sync the UI.
    @_updateUi()
  ).observes('preferences.serverMentionEmail',
             'preferences.serverOneToOneEmail')

  _updateUi: ->
    Ember.run.schedule 'afterRender', @, ->
      prefs = @get('preferences')
      @$('.server-mention-email-checkbox').prop('checked', prefs.get('serverMentionEmail'))
      @$('.server-one-to-one-email-checkbox').prop('checked', prefs.get('serverOneToOneEmail'))

  actions:

    chooseAvatarFile: ->
      @$('.avatar-file-input').trigger('click')
      return undefined

    hideDialog: ->
      @get('targetObject').send('hide')
      return undefined

    changeClientPref: ->
      @set('preferences.clientWeb.showJoinLeaveMessages', @$('#show-join-leave-messages-checkbox').is(':checked'))
      @set('preferences.clientWeb.showAvatars', @$('#show-avatars-checkbox').is(':checked'))
      return undefined

    changeServerPreference: ->
      data =
        server_mention_email: @$('.server-mention-email-checkbox').is(':checked')
        server_one_to_one_email: @$('.server-one-to-one-email-checkbox').is(':checked')
      App.get('api').updatePreferences(data)
      return undefined
