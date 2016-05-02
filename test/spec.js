var currentFile = require('fs').absolute(require('system').args[4])
var index = currentFile + '/../../static/index.html'


casper.test.begin('Page Title', 1, function (test) {
  casper.start(index)
  casper.then(function () {
    test.assertTitle('fooMail', 'Page title is the one expected')
  })
  casper.run(function () {
    test.done()
  })
})


casper.test.begin('Login', 5, function (test) {

  var host = 'test.com'
  var email = 'test@test.com'
  var password = 'secret'

  casper.start(index)
  casper.then(function () {
    test.assertVisible('#login-modal', 'Login popup is shown initially')

    this.sendKeys('#login-host', host)
    this.sendKeys('#login-email', email)
    this.sendKeys('#login-password', password)
    this.click('#login-button')
    casper.waitWhileVisible('#login-modal', function () {
      test.assertInvisible('#login-modal', 'Login popup is dismissed after submitting')
    })

    test.assertEquals(localStorage.getItem('host'), host)
    test.assertEquals(localStorage.getItem('email'), email)
    test.assertEquals(localStorage.getItem('password'), password)
  })
  casper.run(function () {
    test.done()
  })
})
