# Common methods for joining rooms.
App.JoinUtil = Ember.Object.extend()

App.JoinUtil.reopenClass

  loadGroupFromJoinCode: (controller, joinCode) ->
    controller.set('userMessage', null)
    App.Group.fetchByJoinCode(joinCode)
    .then (json) =>
      if ! json? || json.error?
        controller.set('userMessage', App.userMessageFromError(json))
        return
      # Load everything from the response.
      group = App.Group.loadSingle(json)
      if group?
        group.set('isDeleted', false)
        controller.set('model', group)
        controller.set('room', group)
    , (xhr) =>
      controller.set('userMessage', App.userMessageFromError(xhr))
    .fail App.rejectionHandler
