## Install

    npm install -g grunt-cli
    cp config/index.coffee.sample config/index.coffee

## Development

Configure hosts in `config/index.coffee`.  If you want to point at a local API
server, for example, this is where you specify that.

Run `grunt` in one terminal to compile handlebars templates to js.  It will
watch for changes so that you can develop.

    grunt

Run the web server.  It will default to port 3001.

    ./node_modules/node-dev/bin/node-dev server.js

## Commands

Build all files.

    grunt build

Build all files and watch for changes.

    grunt

Run the web server.

    node server.js

Run the web server and watch for changes.

    ./node_modules/node-dev/bin/node-dev server.js
