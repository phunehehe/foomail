var slice = [].slice

window.FM = window.FM || {}
FM = window.FM


var getCredentials = function () {
    return {
        cHost: localStorage.getItem('host'),
        cEmail: localStorage.getItem('email'),
        cPassword: localStorage.getItem('password'),
    }
}


FM.makeUrl = function () {
  var p, parts
  parts = 1 <= arguments.length ? slice.call(arguments, 0) : []
  return '#' + ((function () {
    var i, len, results
    results = []
    for (i = 0, len = parts.length; i < len; i++) {
      p = parts[i]
      results.push(encodeURIComponent(p))
    }
    return results
  })()).join('/')
}

FM.makeId = function () {
  var p, parts
  parts = 1 <= arguments.length ? slice.call(arguments, 0) : []
  return ((function () {
    var i, len, results
    results = []
    for (i = 0, len = parts.length; i < len; i++) {
      p = parts[i]
      results.push(p.toString().replace(/\W/g, ''))
    }
    return results
  })()).join('-')
}

FM.postJSON = function (url, data, callback) {
  return $.ajax({
    url: url,
    type: 'POST',
    data: JSON.stringify(data),
    contentType: 'application/json',
    success: callback,
  })
}

FM.getJSON = function (url, data, callback) {
  return $.get(url, data, callback, 'json')
}


var FM, createReact, showContact

createReact = function (arg) {
  return React.createFactory(React.createClass(arg))
}

showContact = function (contact) {
  return contact.cName + ' <' + contact.cAddress + '>'
}

FM.MailboxList = createReact({
  displayName: 'MailboxList',
  getInitialState: function () {
    return { mailboxes: null }
  },
  render: function () {
    var mailboxNodes
    if (!this.state.mailboxes) {
      return React.DOM.div(null, 'Loading...')
    }
    mailboxNodes = this.state.mailboxes.map(function (mailbox) {
      return FM.Mailbox({
        id: mailbox,
        key: mailbox,
      })
    })
    return React.DOM.div({ className: 'panel-group' }, mailboxNodes)
  },
})

FM.Mailbox = createReact({
  displayName: 'Mailbox',
  getInitialState: function () {
    return {
      messageCount: null,
      currentPage: 1,
      messages: null,
    }
  },
  loadMessages: function () {
    return FM.postJSON('/api/message/list', {
      lmrCredentials: getCredentials(),
      lmrMailbox: this.props.id,
      lmrPage: this.state.currentPage,
    }, (function (_this) {
      return function (data) {
        return _this.setState({ messages: data })
      }
    })(this))
  },
  componentDidMount: function () {
    this.safeID = FM.makeId(this.props.id)
    $(document).on('show.bs.collapse', '#' + this.safeID, this.loadMessages)
    return FM.postJSON('/api/message/count', {
      cmrCredentials: getCredentials(),
      cmrMailbox: this.props.id,
    }, (function (_this) {
      return function (data) {
        return _this.setState({ messageCount: data })
      }
    })(this))
  },
  handleClick: function (page) {
    this.setState({ currentPage: page })
    return this.loadMessages()
  },
  renderMessage: function (uid, subject, sender, date, contents) {
    var url
    url = FM.makeId(this.safeID, uid)
    return React.DOM.div(
      {
        className: 'panel panel-default',
        key: url,
      },
      React.DOM.div({ className: 'panel-heading' },
        React.DOM.div({ className: 'panel-title row' },
          React.DOM.div({ className: 'col-md-4' }, React.DOM.a(
            {
              'data-toggle': 'collapse',
              href: '#' + url,
            },
            subject
          )),
          React.DOM.div({ className: 'col-md-4' }, showContact(sender)),
          React.DOM.div({ className: 'col-md-4' }, date)
        )
      ),
      React.DOM.pre(
        {
          id: url,
          className: 'panel-collapse collapse',
        },
        contents[0]
      )
    )
  },
  render: function () {
    var badge, messageList, messageNodes, pager
    badge = this.state.messageCount
      ? React.DOM.span({ className: 'badge' }, this.state.messageCount)
      : ''
    pager = this.state.messageCount
      ? FM.Pager({
          currentPage: this.state.currentPage,
          handleClick: this.handleClick,
          totalItems: this.state.messageCount,
        })
      : 'Loading...'
    messageList = this.state.messages ? (messageNodes = this.state.messages.map((function (_this) {
      return function (message) {
        return _this.renderMessage(message.mUid, message.mSubject, message.mSender, message.mDate, message.mContents)
      }
    })(this)), React.DOM.div(null, messageNodes)
    ) : React.DOM.div(null, 'Loading...')
    return React.DOM.div({ className: 'panel panel-default' },
      React.DOM.div({ className: 'panel-heading' },
        React.DOM.h4({ className: 'panel-title' }, React.DOM.a(
          {
            'data-toggle': 'collapse',
            href: '#' + this.safeID,
          },
          this.props.id, badge
        ))
      ),
      React.DOM.div(
        {
          id: this.safeID,
          className: 'panel-collapse collapse',
        },
        React.DOM.div({ className: 'panel-body' }, messageList),
        React.DOM.div({ className: 'text-center' }, pager)
      )
    )
  },
})

FM.PagerItem = createReact({
  displayName: 'PagerItem',
  handleClick: function () {
    return this.props.handleClick(this.props.target)
  },
  render: function () {
    var ref
    if (this.props.currentPage === this.props.target) {
      return React.DOM.li({ className: 'active' },
        React.DOM.span(null, this.props.text)
      )
    } else if ((0 < (ref = this.props.target) && ref <= this.props.total)) {
      return React.DOM.li({ onClick: this.handleClick },
        React.DOM.span(null, this.props.text)
      )
    } else {
      return React.DOM.li({ className: 'disabled' },
        React.DOM.span(null, this.props.text)
      )
    }
  },
})

FM.Pager = createReact({
  displayName: 'Pager',
  render: function () {
    var i, items, makePagerItem, next, previous, totalPages
    totalPages = Math.ceil(this.props.totalItems / 10)
    makePagerItem = (function (_this) {
      return function (target, text) {
        if (text == null) {
          text = target
        }
        return FM.PagerItem({
          key: target,
          currentPage: _this.props.currentPage,
          target: target,
          total: totalPages,
          handleClick: _this.props.handleClick,
          text: text,
        })
      }
    })(this)
    previous = makePagerItem(this.props.currentPage - 1, '«')
    next = makePagerItem(this.props.currentPage + 1, '»')
    items = (function () {
      var j, ref, results
      results = []
      for (i = j = 1, ref = totalPages; 1 <= ref ? j <= ref : j >= ref; i = 1 <= ref ? ++j : --j) {
        results.push(makePagerItem(i))
      }
      return results
    })()
    return React.DOM.ul({ className: 'pagination' }, previous, items, next)
  },
})

FM.Alert = createReact({
  displayName: 'Alert',
  render: function () {
    if (this.props.code && this.props.message) {
      return React.DOM.div({
        className: 'alert alert-danger',
        role: 'alert',
      }, React.DOM.strong(null, this.props.code), ': ', this.props.message)
    }
  },
})


// var relogin = function (data) {
//   ReactDOM.render(FM.Alert({
//     code: data.code,
//     message: data.message
//   }), document.getElementById('login-alert'))
//   return $('#login-modal').modal()
// }

var fetchMailboxes = function () {
  var callback
  callback = function (data) {
    return FM.mailboxList.setState({ mailboxes: data })
  }
  return FM.postJSON('/api/mailbox/list', getCredentials(), callback)
}

// var fetchMessages = function (mailbox, page, callback) {
//   return FM.postJSON('/api/message/list', {
//     lmrCredentials: {
//       cHost: FM.host,
//       cEmail: FM.email,
//       cPassword: FM.password
//     },
//     lmrMailbox: mailbox,
//     lmrPage: page
//   }, callback)
// }

var fetch = function () {
  // var query = window.location.hash.substring(1).split('/')
  // var action = query[0] || 'list'
  // var mailbox = query[1] || 'INBOX'
  // var item = query[2] || 1
  return fetchMailboxes()
}

$(window).on('hashchange', function () {
  return fetch()
})

$('#refresh-button').click(function () {
  return fetch()
})

$('#login-modal').on('shown.bs.modal', function () {
  return $('#login-email').focus()
})

$('#compose-button').click(function () {
  return $('#compose-modal').modal()
})

$('#compose-modal').on('shown.bs.modal', function () {
  return $('#compose-recipients').focus()
})

$('#login-modal').on('hide.bs.modal', function () {
  localStorage.setItem('host', $('#login-host').val())
  localStorage.setItem('email', $('#login-email').val())
  localStorage.setItem('password', $('#login-password').val())
  fetch()
})

$('#compose-submit').click(function () {
  // var message, recipients, subject
  // recipients = $('#compose-recipients').val()
  // subject = $('#compose-subject').val()
  // message = $('#compose-message').val()
  // console.log('Sending message ' + subject + ' to ' + recipients + ': ' + message)
  return $('#compose-modal').modal('hide')
})

FM.mailboxList = ReactDOM.render(FM.MailboxList(), document.getElementById('mailbox-list'))

if (
    localStorage.getItem('host')
 && localStorage.getItem('email')
 && localStorage.getItem('password')
) {
  fetch()
} else {
  $('#login-modal').modal()
}
