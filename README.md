# NAME

DK Hostmaster DSU service demo client

# VERSION

This documentation describes version 1.0.0

# INTRODUCTION

This is a pretty basic client for demonstrating DK Hostmaster's DSU protocol.

The protocol is a HTTP based API for uploading and deleting DS keys for a given domain for the .dk registry administered by DK Hostmaster A/S.

The client is intended for demonstration and does not validate entered data in order to be able to demonstrate error scenarios as well as expected use.

The client is implemented in Perl using the Mojolicious framework (see dependencies below).

# USAGE

    $ morbo  client.pl

Open your browser at:

    http://127.0.0.1:3000/

# DEPENDENCIES

This client is implemented using Mojolicious::Lite in addition the following
Perl modules are used all available from CPAN.

- [Readonly](https://metacpan.org/pod/Readonly)
- [Mojo::UserAgent](https://metacpan.org/pod/Mojo::UserAgent)

In addition to the Perl modules, the client uses [Twitter Bootstrap](http://getbootstrap.com/) and hereby jQuery. These are automatically downloaded via CDNs and are not distributed with the client software.

# SEE ALSO

The main site for this client is the Github repository.

- https://github.com/DK-Hostmaster/dsu-demo-client-mojolicious

For information on the service, please refer to the documentation page with
DK Hostmaster.

- https://www.dk-hostmaster.dk/english/technical-administration/tech-notes/dnssec/dsu

# COPYRIGHT

This software is under copyright by DK Hostmaster A/S 2015

# LICENSE

This software is licensed under the MIT software license

Please refer to the LICENSE file accompanying this file.
