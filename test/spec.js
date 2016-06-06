var currentFile = require('fs').absolute(require('system').args[4])
var index = currentFile + '/../../static/index.html'

var host = 'test.com'
var email = 'test@test.com'
var password = 'secret'


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

  localStorage.clear()
  casper.start(index)

  casper.then(function () {

    test.assertVisible('#login-modal', 'Login popup is shown initially')

    this.sendKeys('#login-host', host)
    this.sendKeys('#login-email', email)
    this.sendKeys('#login-password', password)
    this.click('#login-button')

    casper.waitWhileVisible('#login-modal', function () {
      test.pass('Login popup is dismissed after submitting')

      test.assertEquals(localStorage.getItem('host'), host, 'Host is saved in local storage')
      test.assertEquals(localStorage.getItem('email'), email, 'Email is saved in local storage')
      test.assertEquals(localStorage.getItem('password'), password, 'Password is saved in local storage')
    })
  })
  casper.run(function () {
    test.done()
  })
})


casper.test.begin('Forget Me Not', 1, function (test) {

  localStorage.setItem('host', host)
  localStorage.setItem('email', email)
  localStorage.setItem('password', password)

  casper.start(index)
  casper.then(function () {
    test.assertInvisible('#login-modal', 'Login popup is not shown if there are saved credentials')
  })
  casper.run(function () {
    test.done()
  })
})
