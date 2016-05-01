var currentFile = require('fs').absolute(require('system').args[4])
var index = currentFile + '/../../static/index.html'

casper.test.begin('fooMail', 1, function suite (test) {
  casper.start(index)
  casper.then(function () {
    test.assertTitle('fooMail', 'Page title is the one expected')
  })
  casper.run(function () {
    test.done()
  })
})
