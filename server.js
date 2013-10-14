require('coffee-script');

var express = require('express');
var http = require('http');
var path = require('path');

var app = express();

app.set('port', process.env.PORT || 3001);
app.set('views', __dirname + '/views');
app.set('view engine', 'jade');
app.use(express.favicon());
app.use(express.logger('short'));
app.use(express.bodyParser());
app.use(app.router);
app.use(express.static(path.join(__dirname, 'public')));

app.configure('development', function() {
  app.use(express.errorHandler({
    dumpExceptions: true,
    showStack: true
  }));
});

app.get('/', function(req, res) {
  res.render('index', { title: "Chat App" });
});

http.createServer(app).listen(app.get('port'), function() {
  console.log("Express server listening on port %d in %s mode",
              app.get('port'), app.get('env'));
});
