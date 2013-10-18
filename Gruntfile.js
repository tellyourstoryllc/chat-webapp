module.exports = function(grunt) {

  grunt.initConfig({

    /*
      Watch files for changes.

      Changes to any templates will trigger the emberTemplates
      task (which writes a new compiled file into templates.js).
    */
    watch: {
      handlebars_templates: {
        files: ['assets/templates/**/*.hbs'],
        tasks: ['emberTemplates']
      }
    },

    /* 
      Finds Handlebars templates and precompiles them into functions.
      The provides two benefits:

      1. Templates render much faster
      2. We only need to include the handlebars-runtime microlib
         and not the entire Handlebars parser.

      Files will be written out to assets/js/templates.js
      which is required within the project files so will end up
      as part of our application.
    */
    emberTemplates: {
      options: {
        templateName: function(sourceFile) {
          return sourceFile.replace(/assets\/templates\//, '').replace(/\.hbr$/, '');
        }
      },
      'assets/js/templates.js': ["assets/templates/**/*.hbs"]
    }
  });
  
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-ember-templates');

  /*
    Default task. Compiles templates and begins watching for changes.
  */
  grunt.registerTask('default', ['emberTemplates', 'watch']);

  /*
    Build everything after a new deploy.  Right now just compiles templates.
  */
  grunt.registerTask('build', ['emberTemplates']);
};
