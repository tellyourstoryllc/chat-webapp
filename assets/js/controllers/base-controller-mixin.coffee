App.BaseControllerMixin = Ember.Mixin.create

  isLoggedIn: (->
    App.isLoggedIn()
  ).property('App.currentUser')

  # When this is supported, we can read files locally and show image previews,
  # for example.
  doesBrowserSupportFileReader: (->
    Modernizr.filereader
  ).property()

  # Returns true if the browser can both select the file and upload it via AJAX.
  doesBrowserSupportAjaxFileUpload: (->
    App.doesBrowserSupportAjaxFileUpload()
  ).property()