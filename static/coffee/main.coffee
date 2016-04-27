window.FM = window.FM || {}
FM = window.FM


relogin = (data) ->
  ReactDOM.render(
    Alert({
      code: data.code
      message: data.message
    })
    document.getElementById('login-alert')
  )
  $('#login-modal').modal()


fetchMailboxes = ->
  callback = (data) -> FM.mailboxList.setState({
    mailboxes: data
  })
  FM.postJSON(
    '/api/mailbox/list'
    {
      cHost: FM.host
      cEmail: FM.email
      cPassword: FM.password
    }
    callback
  )


fetchMessages = (mailbox, page, callback) ->
  FM.postJSON(
    '/api/message/list'
    {
      lmrCredentials: {
        cHost: FM.host
        cEmail: FM.email
        cPassword: FM.password
      }
      lmrMailbox: mailbox
      lmrPage: page
    }
    callback
  )


# TODO: cancel previous fetches
fetch = ->

  query = window.location.hash.substring(1).split('/')
  action = query[0] or 'list'
  mailbox = query[1] or 'INBOX'
  item = query[2] or 1

  fetchMailboxes()



$(window).on('hashchange', -> fetch())
$('#refresh-button').click( -> fetch())
$('#login-modal').on('shown.bs.modal', -> $('#login-email').focus())
$('#compose-button').click( -> $('#compose-modal').modal())
$('#compose-modal').on('shown.bs.modal', -> $('#compose-recipients').focus())

$('#login-modal').on(
  'hide.bs.modal'
  ->
    document.cookie = JSON.stringify({
      host: $('#login-host').val()
      email: $('#login-email').val()
      password: $('#login-password').val()
    })
    FM.host = $('#login-host').val()
    FM.email = $('#login-email').val()
    FM.password = $('#login-password').val()
    fetch()
)

$('#compose-submit').click ->
  recipients = $('#compose-recipients').val()
  subject = $('#compose-subject').val()
  message = $('#compose-message').val()
  console.log("Sending message #{subject} to #{recipients}: #{message}")
  $('#compose-modal').modal('hide')


# Do it!

FM.mailboxList = ReactDOM.render(
  FM.MailboxList()
  document.getElementById('mailbox-list')
)

try

  cookies = JSON.parse(document.cookie)
  FM.host = cookies.host
  FM.email = cookies.email
  FM.password = cookies.password
  fetch()

catch error

  console.log(error)
  # FIXME: This doesn't quite work yet
  $('#login-modal').modal()
