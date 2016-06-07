var currentFile = require('fs').absolute(require('system').args[4])
var index = currentFile + '/../../static/index.html'

var host = 'test.com'
var email = 'test@test.com'
var password = 'secret'


var log = function (thing) {
  // Error because we never expect messages
  casper.log(JSON.stringify(thing), 'error')
}

var events = [
  'error',
  'page.error',
  'remote.message',
  'resource.error',
]
events.forEach(function (e) {
  casper.on(e, log)
})

casper.test.begin('Page Title', 1, function (test) {
  casper.start(index)
  casper.then(function () {
    test.assertTitle('fooMail', 'Page title is the one expected')
  })
  casper.run(function () {
    test.done()
  })
})


casper.test.begin('Login', 4, function (test) {

  localStorage.clear()
  casper.start(index)

  casper.then(function () {

    this.page.evaluate(function () {
      window.FM.ajaxMock = function (args) {
        args.success(['test mailbox'])
      }
    })

    test.assertVisible('#login-modal', 'Login popup is shown initially')

    this.sendKeys('#login-host', host)
    this.sendKeys('#login-email', email)
    this.sendKeys('#login-password', password)
    this.click('#login-button')

    casper.waitWhileVisible('#login-modal', function () {
      test.pass('Login popup is dismissed after submitting')

        test.assertEquals([
          localStorage.getItem('email'),
          localStorage.getItem('host'),
          localStorage.getItem('password'),
        ], [email, host, password], 'Credentials are saved in local storage')

        casper.waitUntilVisible('#mailbox-list .panel-group', function () {
          test.pass('Credentials are used to get mailbox list')
        })
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
