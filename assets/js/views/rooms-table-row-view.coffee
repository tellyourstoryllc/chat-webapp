App.RoomsTableRowView = Ember.View.extend
  tagName: 'tr'

  newName: ''

  actions:

    renameRoom: (group) ->
      @set('isRenaming', true)
      @set('newName', group.get('name'))
      Ember.run.schedule 'afterRender', @, ->
        $name = @$('.new-name')
        $name.textrange('set') # Select all.
        $name.focus()
      return undefined

    cancelRenamingRoom: ->
      @set('isRenaming', false)
      return undefined

    saveRoomName: (group) ->
      @set('isRenaming', false)
      newName = @get('newName')?.trim()
      oldName = group.get('name')
      return if Ember.isEmpty(newName)

      api = App.get('api')
      url = api.buildURL("/groups/#{group.get('id')}/update")
      group.withLockedPropertyTransaction url, 'POST', data: { name: newName }
      , 'name', =>
        group.set('name', newName)
      ,  =>
        group.set('name', oldName)
      return undefined
