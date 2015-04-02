
# Helper functions

makeUrl = (parts...) -> '#' + parts.join('/')


Message = React.createClass({
    displayName: 'Message'
    render: ->
        React.DOM.tr(null,
            React.DOM.td(null, React.DOM.a({href: makeUrl('view', this.props.mailbox, this.props.message.mUid)},
                this.props.message.mSubject
            )),
            React.DOM.td(null, this.props.message.mSender),
            React.DOM.td(null, this.props.message.mDate)
        )
});


Pagination = React.createClass({
    displayName: 'Pagination',
    render: ->

        if this.props.currentPage > 1
            previous = React.DOM.li(null, React.DOM.a({
                href: makeUrl('list', this.props.mailbox, this.props.currentPage - 1)
            }, "«"))
        else
            previous = React.DOM.li({className: "disabled"}, React.DOM.span(null, "«"))

        if this.props.currentPage < this.props.total
            next = React.DOM.li(null, React.DOM.a({
                href: makeUrl('list', this.props.makeUrl, this.props.currentPage + 1)
            }, "»"))
        else
            next = React.DOM.li({className: "disabled"}, React.DOM.span(null, "»"))

        items = [];
        # TODO: handle a large number of pages
        for i in [1..this.props.total]
            if i == this.props.loadingPage
                item = React.DOM.li({className: "disabled"}, React.DOM.span(null, i));
            else if i == this.props.currentPage
                item = React.DOM.li({className: "active"},
                    React.DOM.span(null, i, " ", React.DOM.span({className: "sr-only"}, "(current)"))
                );
            else
                item = React.DOM.li(null,
                    React.DOM.a({href: makeUrl('list', this.props.mailbox, i)}, i)
                );
            items.push(item)

        return React.DOM.ul({className: "pagination"}, previous, items, next)
})



window.MessageList = React.createClass({
    displayName: 'MessageList'

    getInitialState: -> {
            currentMailbox: null,
            currentPage: null,
            loadingPage: null,
            message: null,
            messages: null,
            pages: null
    }


    safeUpdate: (mailbox, page, stateChanges) ->
        if mailbox == this.state.currentMailbox and page == this.state.currentPage
            this.setState(stateChanges)


    renderList: ->

        currentMailbox = this.state.currentMailbox;
        messageNodes = this.state.messages.map((message) ->
            Message({mailbox: currentMailbox, message: message})
        )

        return React.DOM.div(null,
            React.DOM.table({className: "table table-striped table-hover"},
                React.DOM.thead(null,
                    React.DOM.tr(null,
                        React.DOM.th(null, "Subject"),
                        React.DOM.th(null, "From"),
                        React.DOM.th(null, "Date")
                    )
                ),
                React.DOM.tbody(null,
                    messageNodes
                )
            ),
            React.DOM.div({className: "text-center"},
                Pagination({
                    total: this.state.pages,
                    mailbox: currentMailbox,
                    currentPage: this.state.currentPage,
                    loadingPage: this.state.loadingPage
                })
            )
        );


    renderSingle: ->
        message = this.state.message
        React.DOM.div(null,
            React.DOM.dl({className: "dl-horizontal"},
                React.DOM.dt(null, "Subject"),
                React.DOM.dd(null, message.message_subject),
                React.DOM.dt(null, "From"),
                React.DOM.dd(null, message.message_sender),
                React.DOM.dt(null, "Date"),
                React.DOM.dd(null, message.date)
            ),
            React.DOM.pre(null,
                this.state.message.contents[0]
            )
        )


    render: ->
        if this.state.message
            return this.renderSingle()
        else if this.state.messages
            return this.renderList()
        else
            return React.DOM.div(null, "Loading...")
})


Mailbox = React.createClass({
    displayName: 'Mailbox'

    render: ->

        if this.props.name == this.props.loadingMailbox
            className = 'disabled list-group-item'
        else if this.props.name == this.props.currentMailbox
            className = 'active list-group-item';
        else
            className = 'list-group-item';

        return React.DOM.a({href: makeUrl('list', this.props.name), className: className},
            React.DOM.span({className: "badge"}, 14),
            this.props.name
        )
});


window.MailboxList = React.createClass({
    displayName: 'MailboxList',

    render: ->

        if !this.state || !this.state.mailboxes
            return React.DOM.div(null, "Loading...");

        loadingMailbox = this.state.loadingMailbox;
        currentMailbox = this.state.currentMailbox;
        mailboxNodes = this.state.mailboxes.map((mailbox) ->
            Mailbox({
                loadingMailbox: loadingMailbox
                currentMailbox: currentMailbox
                name: mailbox
            })
        )

        return React.DOM.div({className: "list-group"},
            mailboxNodes
        )
})


Alert = React.createClass({
    displayName: 'Alert',
    render: ->
        if this.props.code && this.props.message
            return React.DOM.div({className: "alert alert-danger", role: "alert"},
                React.DOM.strong(null, this.props.code), ": ", this.props.message
            );
})
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


getJSON = (url, data, callback) ->
    $.post(url, JSON.stringify(data), callback, 'json')



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
    getJSON('/api/mailbox/list', {
        cHost: 'mail.phunehehe.net'
        cEmail: window.email
        cPassword: window.password
    }, callback)


fetchMessages = (mailbox, page, callback) ->
    getJSON('/api/message/list', {
        lmrCredentials: {
            cHost: 'mail.phunehehe.net'
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
                # TODO: stub
                pages: 1
                messages: data
            })
            fetchMessages(mailbox, item, callback)
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
