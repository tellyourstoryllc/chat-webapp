###########################################################
# Mobile
#
# https://gist.github.com/danott/855078

Modernizr.addTest "ipad", ->
  !! navigator.userAgent.match(/iPad/i)

Modernizr.addTest "iphone", ->
  !! navigator.userAgent.match(/iPhone/i)

Modernizr.addTest "ipod", ->
  !! navigator.userAgent.match(/iPod/i)

Modernizr.addTest "appleios", ->
  Modernizr.ipad || Modernizr.ipod || Modernizr.iphone

Modernizr.addTest "android", ->
  !! navigator.userAgent.match(/Android/i)
