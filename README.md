# fooMail

[![pipeline status](https://gitlab.com/phunehehe/foomail/badges/master/pipeline.svg)](https://gitlab.com/phunehehe/foomail/commits/master)

fooMail is a webmail application. It can be used as a client of any mail
servers supporting IMAP and SMTP (i.e. most if not all of them).


## Another webmail? Why?

Because I want a webmail that can be used with
[CSP](https://en.wikipedia.org/wiki/Content_Security_Policy) and
[PGP](https://en.wikipedia.org/wiki/Pretty_Good_Privacy).

There are existing webmail applications that support PGP. These applications
need to use and protect private PGP keys in the context of user-generated and
potentially malicious contents.

With CSP, the risk is substantially reduced, as browsers will only allow
contents/scripts that you appoint. Sadly, existing applications use large
amounts of inline scripts, which defeats the purpose of CSP.

Removing the inline scripts is a ton of work. If I were to put in that much
work, I might as well write something new and have some fun :P


## How do I use it?

Maybe not yet, unless you want to help making it. The SMTP part is not done, so
sending emails doesn't work yet. PGP support is even further away. Good thing
is, CSP support is there right from the start ;)


## Where is the Cabal file?

So you noticed that the server piece is written in Haskell :) Find it as an
[artifact](https://gitlab.com/phunehehe/foomail/builds/artifacts/master/browse?job=cabal).

I'm not a fan of custom file formats and I use
[Nix](https://nixos.org/nixpkgs/manual/#users-guide-to-the-haskell-infrastructure),
so the Cabal file has no place in Git. However it is pretty much the lowest
common denominator and I sometimes need it too. A build output, then.
