mailboxList = React.renderComponent(
    FM.MailboxList(),
    document.getElementById('mailbox-list')
)

return


# GUI functions


relogin = (data) ->
    React.renderComponent(
        Alert({code: data.code, message: data.message}),
        document.getElementById('login-alert')
    )
    $('#login-modal').modal()


fetchMailboxes = ->
    callback = (data) -> fooMail.setState({
        mailboxes: data
    })
    FM.postJSON('/api/mailbox/list', {
        cHost: window.host
        cEmail: window.email
        cPassword: window.password
    }, callback)


fetchMessages = (mailbox, page, callback) ->
    FM.postJSON('/api/message/list', {
        lmrCredentials: {
            cHost: window.host
            cEmail: window.email
            cPassword: window.password
        }
        lmrMailbox: mailbox
        lmrPage: page
    }, callback)


# TODO: cancel previous fetches
fetch = (force) ->

    query = window.location.hash.substring(1).split('/')
    action = query[0] or 'list'
    mailbox = query[1] or 'INBOX'
    item = query[2] or 1

    fooMail.setState({
        mailbox: mailbox
        currentPage: item
    })

    return

    # Skip loading the mailbox list, unless the user clicks on a mailbox or the
    # refresh button
    if force or query.length == 2
        fooMail.setState({
            currentMailbox: mailbox
        })
        fetchMailboxes()

    switch action
        when 'list'
            console.log('TODO')
            #messageList.setState({
            #    currentMailbox: mailbox
            #    currentPage: item
            #    loadingPage: item
            #    message: null
            #})
            #callback = (data) -> messageList.safeUpdate(mailbox, item, {
            #    loadingPage: null
            #    messages: data
            #})
            #fetchMessages(mailbox, item, callback)
        when 'view'
            if messageList.state.messages
                messages = (m for m in messageList.state.messages when m.uid == item)
                if messages.length == 1
                    messageList.setState({message: messages[0]})
            else
                callback = (data) ->
                    messageList.setState({message: data})
                fetchMessages({
                    mailbox: mailbox
                    uid: item
                }, callback)



# Events

$(window).on 'hashchange', -> fetch()

$('#refresh-button').click -> fetch(true)

$('#login-modal').on 'shown.bs.modal', ->
    $('#login-email').focus()

$('#login-modal').on 'hide.bs.modal', ->
    window.host = 'mail.phunehehe.net'
    window.email = $('#login-email').val()
    window.password = $('#login-password').val()
    fetch(true)

$('#compose-button').click ->
    $('#compose-modal').modal()

$('#compose-modal').on 'shown.bs.modal', ->
    $('#compose-recipients').focus()

$('#compose-submit').click ->
    recipients = $('#compose-recipients').val()
    subject = $('#compose-subject').val()
    message = $('#compose-message').val()
    console.log "Sending message #{subject} to #{recipients}: #{message}"
    $('#compose-modal').modal('hide')


# Do it!

$('#login-modal').modal()
