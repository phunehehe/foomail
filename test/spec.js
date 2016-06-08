var currentFile = require('fs').absolute(require('system').args[4])
var index = 'file://' + currentFile + '/../../static/index.html'

var host = 'test.com'
var email = 'test@test.com'
var password = 'secret'

var mailboxName = 'first mailbox'
var mailboxID = 'first-mailbox'
var mailboxSelector = 'a[href="#' + mailboxID + '"]'

var messageUID = 123
var messageID = mailboxID + '/' + messageUID
var messageSelector = 'a[href="#' + messageID + '"]'

var contentsSelector = '[id="' + messageID + '"]'


var log = function (thing) {
  // Error because we never expect messages
  casper.test.error(thing)
}

var setCredentials = function () {
  localStorage.setItem('host', host)
  localStorage.setItem('email', email)
  localStorage.setItem('password', password)
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

casper.options.onPageInitialized = function () {
  casper.evaluate(function (mailboxName, messageUID) {
    window.FM = window.FM || {}
    window.FM.ajaxMock = function (args) {
      // TODO: check credentials (requires renaming fields server side)
      switch(args.url) {
        case '/api/mailbox/list':
          args.success([mailboxName])
          break
        case '/api/message/count':
          args.success(42)
          break
        case '/api/message/list':
          args.success([{
            mContents: ['some contents'],
            mSender: {
              cName: 'some name',
              cAddress: 'somebody@somewhere.com',
            },
            mSubject: 'some subject',
            mUid: messageUID,
          }])
          break
      default:
          throw 'Unexpected URL: ' + args.url
      }
    }
  }, mailboxName, messageUID)
}

casper.test.setUp(function () {
  // PhantomJS keeps this state accross runs
  localStorage.clear()
})

casper.test.tearDown(function () {
  // For some reason the page URL seems to be kept between runs
  // TODO: maybe report a CasperJS issue
  casper.clear()
})


casper.test.begin('Login', function (test) {
  casper.start(index, function () {

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

        casper.waitUntilVisible(mailboxSelector, function () {
          test.pass('Mailboxes appear')
        })
      }
    )
  })
  casper.run(function () {
    test.done()
  })
})


casper.test.begin('Remember Me', function (test) {

  setCredentials()
  casper.start(index, function () {

    test.assertInvisible('#login-modal', 'Login popup is not shown if there are saved credentials')

    casper.waitUntilVisible(mailboxSelector, function () {
      test.pass('Mailboxes appear after page loads')
    })
  })
  casper.run(function () {
    test.done()
  })
})


casper.test.begin('Click to View Message', function (test) {

  setCredentials()
  casper.start(index, function () {

    casper.waitUntilVisible(mailboxSelector, function () {
      test.pass('Mailboxes appear after page loads')

      test.assertInvisible(messageSelector, 'But not messages')

      this.click(mailboxSelector)
      casper.waitUntilVisible(messageSelector, function () {
        test.pass('Messages appear after clicking mailbox')

        test.assertInvisible(contentsSelector, 'But not contents')

        this.click(messageSelector)
        casper.waitUntilVisible(contentsSelector, function () {
          test.pass('Contents appear after clicking message')
        })
      })
    })
  })
  casper.run(function () {
    test.done()
  })
})


casper.test.begin('Link to Mailbox', function (test) {

  setCredentials()
  casper.start(index + '#' + mailboxID, function () {

    casper.waitUntilVisible(messageSelector, function () {
      test.pass('Messages appear after page loads')

      test.assertInvisible(contentsSelector, 'But not contents')
    })
  })
  casper.run(function () {
    test.done()
  })
})


casper.test.begin('Link to Message', function (test) {

  setCredentials()
  casper.start(index + '#' + mailboxID + '/' + messageUID, function () {

    casper.waitUntilVisible(contentsSelector, function () {
      test.pass('Contents appear after page loads')
    })
  })
  casper.run(function () {
    test.done()
  })
})
