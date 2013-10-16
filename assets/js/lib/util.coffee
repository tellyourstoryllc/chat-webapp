App.Util = Ember.Object.extend()

App.Util.reopenClass

  escapeRegexp: (str) ->
    (str + '').replace(/([.?*+^$[\]\\(){}|-])/g, "\\$1")
