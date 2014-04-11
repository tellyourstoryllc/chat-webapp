App.FacebookAuthMixin = Ember.Mixin.create

  didInsertElement: ->
    # Only load the Facebook script once when we need it.
    if AppConfig.useFacebookAuth && ! App.get('isFacebookLoaded')
      @loadFacebookLibrary()

  loadFacebookLibrary: ->
    window.fbAsyncInit = =>
      FB.init(
        appId      : AppConfig.facebookAppId # App ID
        #channelUrl : '//WWW.YOUR_DOMAIN.COM/channel.html', # Channel File
        #status     : true, # check login status
        #cookie     : true # enable cookies to allow the server to access the session
      )
      # Additional init code here
      # So we can check that it's been loaded.
      App.set('isFacebookLoaded', true)
      App.get('eventTarget').trigger('didLoadFacebook')

    # Load the SDK Asynchronously
    ((d) ->
       id = 'facebook-jssdk'; ref = d.getElementsByTagName('script')[0]
       return if d.getElementById(id)
       js = d.createElement('script'); js.id = id; js.async = true
       js.src = "//connect.facebook.net/en_US/all.js"
       ref.parentNode.insertBefore(js, ref)
     )(document)

  # Returns a promise that resolves to an object with a facebook id and token.
  # If there is any error or the use cancels, the promise is rejected.
  beginLogInWithFacebookFlow: ->
    return new Ember.RSVP.Promise (resolve, reject) =>
      # Make sure the FB library is loaded.
      App.when App.get('isFacebookLoaded'), App.get('eventTarget'), 'didLoadFacebook', @, =>
        try
          handleLoggedInResponse = (response) =>
            resolve
              facebookId: response.authResponse.userID
              facebookToken: response.authResponse.accessToken
              # For debugging.
              loginStatusResponse: response

          FB.getLoginStatus (response) =>
            try
              if response.status == 'connected'
                # The user is logged in and has authenticated our app before.
                handleLoggedInResponse(response)
              else
                # The user isn't logged in to Facebook, or the user is logged in
                # to Facebook but has not authenticated our app.  Prompt the user
                # to allow the app.
                FB.login (response) =>
                  try
                    if response.authResponse
                      handleLoggedInResponse(response)
                    else
                      # User cancelled login or did not fully authorize.
                      reject(message: "Log in to Facebook and allow the app to continue.")
                  catch e
                    reject(e)
            catch e
              reject(e)
        catch e
          reject(e)
      # Make sure to run inside the click handler to prevent popup blocker.
      , runImmediately: true

  # Returns a promise that resolves to an object with all available user fields.
  # If there is any error or the use cancels, the promise is rejected.
  beginSignUpWithFacebookFlow: ->
    return new Ember.RSVP.Promise (resolve, reject) =>
      # Make sure the FB library is loaded.
      App.when App.get('isFacebookLoaded'), App.get('eventTarget'), 'didLoadFacebook', @, =>
        FB.login (response) =>
          @handleFacebookLoginResponseForSignUp(response, resolve, reject)
        , scope: 'email,user_birthday'
      # Make sure to run inside the click handler to prevent popup blocker.
      , runImmediately: true

  # Callback for FB.login that queries FB and gathers sign up info.
  handleFacebookLoginResponseForSignUp: (response, resolve, reject) ->
    try
      if ! response.authResponse
        # User cancelled login or did not fully authorize.
        reject(message: "Log in to Facebook and allow the app to continue.")
        return

      result =
        facebookId: response.authResponse.userID
        facebookToken: response.authResponse.accessToken
        # For debugging.
        loginResponse: response

      # Get more info about Facebook user.
      FB.api "me?fields=email,last_name,first_name,birthday,gender,picture.type(large)", (response) =>
        try
          if ! response || response.error
            reject(message: "There was an error communicating with Facebook.  Please try again.", response: response)
            return

          # For debugging.
          result.meResponse = response

          # Name.
          result.firstName = response.first_name
          result.lastName = response.last_name

          # Email.
          if response.email
            result.email = response.email

          # Birthdate.
          if response.birthday
            matches = /0?(\d{1,2})\/0?(\d{1,2})\/(\d{2,4})/.exec(response.birthday)
            if matches && matches.length >= 4
              result.birthdateYear = matches[3]
              result.birthdateMonth = matches[1]
              result.birthdateDay = matches[2]

          # Gender.
          if response.gender
            result.gender = response.gender

          # Avatar.
          if response.picture && response.picture.data && ! response.picture.data.is_silhouette
            result.avatarImageUrl = response.picture.data.url

          # Success.
          resolve(result)

        catch e
          # Make sure to capture all errors.
          reject(e)

    catch e
      # Make sure to capture all errors.
      reject(e)
    
    undefined

