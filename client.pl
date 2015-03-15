#!/usr/bin/env perl

use Mojolicious::Lite;
use Mojo::UserAgent;

our $VERSION = '1.0.0';

my $endpoint = 'https://dsu-sandbox.dk-hostmaster.dk/1.0';

my $algorithms = {
    'RSA/SHA-256' => 8, 
    'RSA/SHA-512' => 10,
};
my $digest_types = {
    'SHA-1'   => 1, 
    'SHA-256' => 2,
};

get '/' => sub {
  my $self = shift;

  my $params = $self->req->params->to_hash;

  $self->render('index', 
    version      => $VERSION,
    domain       => 'test.dk',
    userid       => 'TESTUSER-DK',
    password     => 'supersecret',
    params       => $params,
    algorithms   => $algorithms,
    digest_types => $digest_types,
    endpoint     => $endpoint,
  );
};

get '/prepare' => sub {
  my $self = shift;

  my $params = $self->req->params->to_hash;

  if ($params->{action} and $params->{action} eq 'delete') {

    $params->{'keytag.1'}    = 'DS_DELETE';
    $params->{'algorithm.1'}  = 'DS_DELETE';
    $params->{'digest_type.1'} = 'DS_DELETE';
    $params->{'digest.1'}     = 'DS_DELETE';

    foreach my $param (grep !/(\w+\.1|domain|userid|password|endpoint)/, keys %{$params}) {
        delete $params->{$param};        
    }
  }

  $self->render('prepare', 
    version  => $VERSION,
    params   => $params,
  );
};

get '/submit' => sub {
    my $self = shift;

    my $ua = Mojo::UserAgent->new();

    my $message = 'Here the result will be presented if possible';
    my $class   = 'alert alert-info';
    my $code    = 'ENOCODE';
    my $tx = $ua->post($endpoint);

    if (my $res = $tx->success) {
        my $result = $res->body;
        $code   = $tx->res->code;

        app->log->info('Request succeeded, evaluating response (hack)');

        #here be json/text/xml parsing code, but since we only want to demonstrate protocol 
        #and leave the actual use of the result up to the user, we just hack it
        if ($code == 200) {
            $message  = $result;
            $class    = 'alert alert-success';

        } elsif ($code == 400) {
            $code    = $tx->res->headers->header('X-DSU');
            $message = $result;
            $class   = 'alert alert-warning';
        }

    } else {
        $message  = $tx->error->{message};
        $code     = $tx->error->{code};
        $class    = 'alert alert-danger';
    }

    $self->render('submit', 
        version => $VERSION,
        message => $message,
        code    => $code,
        class   => $class,
    );
};

app->start;

__DATA__

@@submit.html.ep
% layout 'default';
% title 'submit';

<form id="form" class="form-horizontal" role="form" action="/" method="GET" accept-charset="UTF-8">

<div class="<%= $class %>" role="alert"><%= $code %>: <%= $message %></div>

<button id="edit" type="submit" class="btn btn-default">Edit the request <span class="glyphicon glyphicon-wrench"></span></button>

</form>

@@prepare.html.ep
% layout 'default';
% title 'prepare';

<form id="form" class="form-horizontal" role="form" action="/" method="GET" accept-charset="UTF-8">

<div class="well well-lg">

<!-- Key parameters -->
% for my $number (1 .. 5) {

    <!-- We only want keysets with all 4 parameters defined -->
    % if ($params->{"keytag.$number"} and $params->{"digest.$number"} and $params->{"digest_type.$number"} and $params->{"algorithm.$number"}) {
        % foreach my $param (grep /$number/, keys %{$params}) {
            <code><%= $param %> = <%= $params->{$param} %></code><br/>
            <input type="hidden" name="<%= $param %>" value="<%= $params->{$param} %>" />
        % }
    % }
% }

<!-- Non key parameters -->
% foreach my $param (grep !/\w+\.\d+/, keys %{$params}) {
    % if ($params->{$param}) {
        <code><%= $param %> = <%= $params->{$param} %></code><br/>
        <input type="hidden" name="<%= $param %>" value="<%= $params->{$param} %>" />
    % }
% }

</div>

<button id="send" type="button" name="send" id="send" class="btn btn-primary">Submit the request to: <%= $params->{endpoint} %> <span class="glyphicon glyphicon-send"></span></button>
<button id="edit" type="submit" class="btn btn-default">Edit the request <span class="glyphicon glyphicon-wrench"></span></button>

</form>

@@option.html.ep
<option value="<%= $value %>"><%= $key %></option>

@@keyset.html.ep
    <fieldset id="fieldset.<%= $number %>">
    <legend>Keyset <%= $number %></legend>
    <div class="form-group" style="width:96%;margin-left: auto;margin-right: auto;">
        <div class="col-xs-2">
        <% my $param = "keytag.$number"; %>
        <label class="control-label" for="keytag">Keytag:</label>
        <input name="keytag.<%= $number %>" id="keytag.<%= $number %>" class="form-control" placeholder="keytag" type="text" name="keytag" value="<%= $params->{$param} %>" />
        </div>
        <div class="col-xs-6">
        <% $param = "digest.$number"; %>
        <label class="control-label" for="digest">Digest:</label>
        <input name="digest.<%= $number %>" id="digest.<%= $number %>" class="form-control" placeholder="digest" type="text" name="digest" value="<%= $params->{$param} %>" />
        </div>
        <div class="col-xs-2">
        <% $param = "digest_type.$number"; %>
        <label class="control-label" for="digest_type">Digest type:</label>
        <select name="digest_type.<%= $number %>" id="digest_type.<%= $number %>" class="form-control">
            % foreach my $digest_type (keys %{$digest_types}) {
            %= include 'option', key => $digest_type, value => $digest_types->{$digest_type};
            % }
        </select>
        </div>
        <div class="col-xs-2">
        <% $param = "algorithm.$number"; %>
        <label class="control-label" for="algorithm">Algorithm:</label>
        <select name="algorithm.<%= $number %>" id="algorithm.<%= $number %>" class="form-control">
            % foreach my $algorithm (keys %{$algorithms}) {
            %= include 'option', key => $algorithm, value => $algorithms->{$algorithm};
            % }
        </select>
        </div>
    </div>
    </fieldset>

@@ index.html.ep
% layout 'default';
% title 'index';

    <form id="form" class="form-horizontal" role="form" action="/prepare" method="GET" accept-charset="UTF-8">
    <!-- this hidden field is manipulated from JS (button clicks) -->
    <input type="hidden" id="action" name="action" value="" />
    <input type="hidden" id="endpoint" name="endpoint" value="<%= $endpoint %>" />

    <div class="form-group">
        <div class="control-group">
            <div class="col-xs-3">
            <label class="control-label" for="domain.name">Domain name:</label>
            <input id="domainname" class="form-control" placeholder="domain name" type="text" name="domain" value="<%= $domain %>" />
            </div>
        </div>
    </div>
    <div class="form-group">
        <div class="control-group">
            <div class="col-xs-2">
            <label class="control-label" for="userid">User-id:</label>
            <input id="userid" class="form-control" placeholder="user-id" type="text" name="userid" value="<%= $userid %>" />
            </div>
        </div>
    </div>

    <!-- keysets -->
    <div id="keysets">
    % for my $keyset (1 .. 5) {
    %= include 'keyset', number => $keyset, algorithms => $algorithms, digest_types => $digest_types
    % }
    </div>
    <p>&nbsp;</p>
    <p>
    <button type="submit" id="prepare" class="btn btn-primary">Prepare addition request</button>
    <button type="button" id="delete" name="delete" class="btn btn-danger">Prepare deletion request</button>
    <button type="reset" class="btn btn-default">Reset to defaults</button>
    <button type="button" id="clear" name="clear" class="btn btn-default">Clear</button>
    </p>

    </form>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta .epp-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><%= title %></title>

    <!-- Bootstrap -->
    <!-- Latest compiled and minified CSS -->
    <link rel="stylesheet" href="https://netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css">
    <!-- Optional theme -->
    <link rel="stylesheet" href="https://netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap-theme.min.css">

    <!-- HTML5 Shim and Respond.js IE8 support of HTML5 elements and media queries -->
    <!-- WARNING: Respond.js doesn't work if you view the page via file:// -->
    <!--[if lt IE 9]>
      <!-- <script src="https://oss.maxcdn.com/libs/html5shiv/3.7.0/html5shiv.js"></script> -->
      <!-- <script src="https://oss.maxcdn.com/libs/respond.js/1.4.2/respond.min.js"></script> -->
    <![endif]-->
  </head>
  <body role="document">
    <div class="container">
    <!-- <a href="https://github.com/DK-Hostmaster/dsu-demo-client-mojolicious"><img style="position: absolute; top: 0; right: 0; border: 0;" src="https://camo.githubusercontent.com/365986a132ccd6a44c23a9169022c0b5c890c387/68747470733a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f7265645f6161303030302e706e67" alt="Fork me on GitHub" data-canonical-src="https://s3.amazonaws.com/github/ribbons/forkme_right_red_aa0000.png"></a>-->
    <h1>DK Hostmaster DSU service demo client - Version <%= $version %></h1>

    <%= content %>

    </div>

    <!-- jQuery (necessary for Bootstrap's JavaScript plugins) -->
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.0/jquery.min.js"></script>
    <!-- Latest compiled and minified JavaScript -->
    <script src="https://netdna.bootstrapcdn.com/bootstrap/3.1.1/js/bootstrap.min.js"></script>
    <script language="javascript">

        // for handling proper reset (clear) of the form
        function resetForm($form) {
            // http://stackoverflow.com/questions/680241/resetting-a-multi-stage-form-with-jquery
            $form.find('input:text, input:password, input:file, select textarea').val('');
            $form.find('input:radio, input:checkbox')
            .removeAttr('checked').removeAttr('selected');
        };

        // for handling actual submit to the endpoint
        function send_to_endpoint() {
            console.log("Calling submit");
            $('#form').attr("action", '/submit');
            $("#form").submit();
        };

        // for handling the click of the send button
        $('#send').on('click', function() {
                send_to_endpoint($('#form'));
            }
        );
      
        // for handling click of the delete button
        $('#delete').on('click', function() {
                $('#action').val('delete');
                $("#form").submit();
            }
        );

        // for handling click of the clear button
        $('#clear').on('click', function() {
                resetForm($('#form'));
            }
        );      
    </script>
    
  </body>
</html>