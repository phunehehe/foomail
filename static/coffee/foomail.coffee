# TODO: these global variables look ugly

window.mailboxList = React.renderComponent(
    window.MailboxList(null),
    document.getElementById('mailbox-list')
)

window.messageList = React.renderComponent(
    window.MessageList(null),
    document.getElementById('message-list')
)



# Helper functions


makeCallback = (callback, errback=console.log) ->
    (response) ->
        if response.success
            callback(response.data)
        else
            errback(response.data)


getJSON = (url, data, callback, errback) ->
    $.post(url, data, makeCallback(callback, errback), 'json')



# GUI functions


relogin = (data) ->
    React.renderComponent(
        Alert({code: data.code, message: data.message}),
        document.getElementById('login-alert')
    )
    $('#login-modal').modal()


fetchMailboxes = ->
    callback = (data) -> window.mailboxList.setState({
        loadingMailbox: null
        mailboxes: data
    })
    getJSON('/api/mailboxes', {
        email: window.email
        password: window.password
    }, callback, relogin)


fetchMessages = (params, callback) ->
    $.extend(params, {
        email: window.email
        password: window.password
    })
    getJSON('/api/list/messages', params, callback, relogin)


# TODO: cancel previous fetches
fetch = (force) ->

    query = window.location.hash.substring(1).split('/')
    action = query[0] or 'list'
    mailbox = query[1] or 'INBOX'
    item = query[2] or 1

    # Skip loading the mailbox list, unless the user clicks on a mailbox or the
    # refresh button
    if force or query.length == 2
        window.mailboxList.setState({
            currentMailbox: mailbox
            loadingMailbox: mailbox
        })
        fetchMailboxes()

    switch action
        when 'list'
            window.messageList.setState({
                currentMailbox: mailbox
                currentPage: item
                loadingPage: item
                message: null
            })
            callback = (data) -> window.messageList.safeUpdate(mailbox, item, {
                    loadingPage: null
                    pages: data[0]
                    messages: data[1]
            })
            fetchMessages({
                mailbox: mailbox
                page: item
            }, callback)
        when 'view'
            if window.messageList.state.messages
                messages = (m for m in window.messageList.state.messages when m.uid == item)
                if messages.length == 1
                    window.messageList.setState({message: messages[0]})
            else
                callback = (data) ->
                    window.messageList.setState({message: data})
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
