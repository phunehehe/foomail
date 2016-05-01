casper.test.begin('fooMail', 1, function suite (test) {
  casper.start('./static/index.html')
  casper.then(function () {
    test.assertTitle('fooMail', 'Page title is the one expected')
  })
  casper.run(function () {
    test.done()
  })
})
