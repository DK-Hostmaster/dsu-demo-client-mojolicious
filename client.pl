#!/usr/bin/env perl

use Mojolicious::Lite;
use Mojo::UserAgent;

our $VERSION = '1.2.0';

my $endpoint = 'https://dsu-sandbox.dk-hostmaster.dk/1.0';

my $algorithms = {
    '8: RSA/SHA-256'                     => 8, 
    '10: RSA/SHA-512'                    => 10,
    '13: ECDSA Curve P-256 with SHA-256' => 13,
    '14: ECDSA Curve P-384 with SHA-384' => 14,
};
my $digest_types = {
    '1: SHA-1'   => 1, 
    '2: SHA-256' => 2,
    '4: SHA-384' => 4,
};

any '/' => sub {
  my $self = shift;

  my $params = $self->req->params->to_hash;

  $self->render('index', 
    version      => $VERSION,
    domain       => 'eksempel.dk',
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

    $params->{'keytag1'}    = 'DS_DELETE';
    $params->{'algorithm1'}  = 'DS_DELETE';
    $params->{'digest_type1'} = 'DS_DELETE';
    $params->{'digest1'}     = 'DS_DELETE';

    foreach my $param (grep !/(\w+1|domain|userid|password|endpoint)/, keys %{$params}) {
        delete $params->{$param};        
    }
  }

  $self->render('prepare',
    version => $VERSION,
    params  => $params,
  );
};

get '/submit' => sub {
    my $self = shift;

    my $ua = Mojo::UserAgent->new();

    my $params = $self->req->params->to_hash;

    my $message = 'Here the result will be presented if possible';
    my $class   = 'alert alert-info';
    my $code    = 'ENOCODE';
    my $subcode = 'ENOSUBCODE';
    my $tx = $ua->post($endpoint);

    if (my $res = $tx->success) {
        my $result = $res->body;
        $code   = $tx->res->code;

        app->log->info('Request succeeded, evaluating response (hack)');

        #here be json/text/xml parsing code, but since we only want to demonstrate protocol 
        #and leave the actual use of the result up to the user, we just hack it
        if ($code == 200) {
            $message  = "Upload of DS records was succesful $result";
            $class    = 'alert alert-success';
            app->log->info($code.' '.$message);

        } elsif ($code == 400) {
            $code    = $tx->res->headers->header('X-DSU');
            $message = "Upload of DS records was unsuccesful $message";
            $class   = 'alert alert-warning';
            app->log->info($code.' '.$message);
        }

    } else {
        $code    //= $tx->error->{code};
        $subcode //= $tx->res->headers->header('X-DSU');
        $message = "Upload of DS records was unsuccesful ".$tx->error->{message};
        $class   = 'alert alert-danger';
        app->log->info($code.' '.$message.'('.$subcode.')');
    }

    $self->render('submit', 
        version => $VERSION,
        message => $message,
        code    => $code,
        subcode => $subcode,
        class   => $class,
        params  => $params,
    );
};

app->start;

__DATA__

@@submit.html.ep
% layout 'default';
% title 'submit';

<form id="form" class="form-horizontal" role="form" action="/" method="GET" accept-charset="UTF-8">

<div class="<%= $class %>" role="alert"><%= $code %>: <%= $message %> (<%= $subcode %>)</div>

<!-- Key parameters -->
% for my $number (1 .. 5) {

    <!-- We respect keysets with any parameters defined -->
    % if ($params->{'keytag'.$number} or $params->{'digest'.$number} or $params->{'digest_type'.$number} or $params->{'algorithm'.$number}) {
        % foreach my $param (grep /$number/, keys %{$params}) {
            <input type="hidden" name="<%= $param %>" value="<%= $params->{$param} %>" />
        % }
    % }
% }

<!-- Non key parameters -->
% foreach my $param (grep !/\w+\d+/, keys %{$params}) {
    % if ($params->{$param}) {
        <input type="hidden" name="<%= $param %>" value="<%= $params->{$param} %>" />
    % }
% }

<button id="edit" type="submit" class="btn btn-default">Edit the request <span class="glyphicon glyphicon-wrench"></span></button>

</form>

@@prepare.html.ep
% layout 'default';
% title 'prepare';

<form id="form" class="form-horizontal" role="form" action="/" method="GET" accept-charset="UTF-8">

<div class="well well-lg">

<!-- Key parameters -->
% for my $number (1 .. 5) {

    <!-- We respect keysets with any parameters defined -->
    % if ($params->{'keytag'.$number} or $params->{'digest'.$number} or $params->{'digest_type'.$number} or $params->{'algorithm'.$number}) {
        % foreach my $param (grep /$number/, keys %{$params}) {
            <code><%= $param %> = <%= $params->{$param} %></code><br/>
            <input type="hidden" name="<%= $param %>" value="<%= $params->{$param} %>" />
        % }
    % }
% }

<!-- Non key parameters -->
% foreach my $param (grep !/\w+\d+/, keys %{$params}) {
    % if ($params->{$param}) {
        <code><%= $param %> = <%= $params->{$param} %></code><br/>
        <input type="hidden" name="<%= $param %>" value="<%= $params->{$param} %>" />
    % }
% }

</div>

<button id="send" type="button" name="send" id="send" class="btn btn-primary">Submit the request to: <%= $params->{endpoint} %> <span class="glyphicon glyphicon-send"></span></button>
% if ($params->{'keytag1'} and $params->{'keytag1'} eq 'DS_DELETE') {
<button id="skip" type="button" class="btn btn-default">Skip the delete request <span class="glyphicon glyphicon-wrench"></span></button>
% } else {
<button id="edit" type="submit" class="btn btn-default">Edit the request <span class="glyphicon glyphicon-wrench"></span></button>
% }

</form>

@@option.html.ep
<option value="<%= $value %>" <%= $selected %>><%= $key %></option>

@@keyset.html.ep
    <fieldset id="fieldset.<%= $number %>">
    <legend>Keyset <%= $number %></legend>
    <div class="form-group" style="width:96%;margin-left: auto;margin-right: auto;">
        <div class="col-xs-2">
        <% my $param = "keytag$number"; %>
        <label class="control-label" for="keytag">Keytag:</label>
        <input name="keytag<%= $number %>" id="keytag<%= $number %>" class="form-control" placeholder="keytag" type="text" name="keytag" value="<%= $params->{$param} %>" />
        </div>
        <div class="col-xs-6">
        <% $param = "digest$number"; %>
        <label class="control-label" for="digest">Digest:</label>
        <input name="digest<%= $number %>" id="digest<%= $number %>" class="form-control" placeholder="digest" type="text" name="digest" value="<%= $params->{$param} %>" />
        </div>
        <div class="col-xs-2">
        <label class="control-label" for="digest_type">Digest type:</label>
        % my $digest_type_selected = 0;
        % if ($params->{'digest_type.'.$number}) {
        %     $digest_type_selected++;
        % }
        <select name="digest_type<%= $number %>" id="digest_type<%= $number %>" class="form-control">
            % if ($digest_type_selected == 0) {
            %=  include 'option', key => '-', value => '', selected => 'selected';
            %   $digest_type_selected++;
            % }
            % foreach my $digest_type (sort keys %{$digest_types}) {
            %     if ($params->{'digest_type'.$number} and $params->{'digest_type'.$number} == $digest_types->{$digest_type}) {
            %=        include 'option', key => $digest_type, value => $digest_types->{$digest_type}, selected => 'selected';
            %     } else {
            %=        include 'option', key => $digest_type, value => $digest_types->{$digest_type}, selected => '';
            %     }
            % }
        </select>
        </div>

        <div class="col-xs-2">
        <label class="control-label" for="algorithm">Algorithm:</label>
        % my $algorithm_selected = 0;
        % if ($params->{'algorithm'.$number}) {
        %     $algorithm_selected++;
        % }
        <select name="algorithm<%= $number %>" id="algorithm<%= $number %>" class="form-control">
            % if ($algorithm_selected == 0) {
            %= include 'option', key => '-', value => '', selected => 'selected';
            %  $digest_type_selected++;
            % }
            % foreach my $algorithm (sort { $algorithms->{$a} <=> $algorithms->{$b} } keys %{$algorithms}) {
            %     if ($params->{'algorithm'.$number} and $params->{'algorithm'.$number} == $algorithms->{$algorithm}) {
            %=        include 'option', key => $algorithm, value => $algorithms->{$algorithm}, selected => 'selected';
            %     } else {
            %=        include 'option', key => $algorithm, value => $algorithms->{$algorithm}, selected => '';
            %     }
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
    <div class="form-group">
        <div class="control-group">
            <div class="col-xs-2">
            <label class="control-label" for="password">Password:</label>
            <input id="password" class="form-control" placeholder="password" type="password" name="password" value="<%= $password %>" />
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

@@ javascript.html.ep
    <script language="javascript">

        // for handling proper reset (clear) of the form
        function resetForm($form) {
            // http://stackoverflow.com/questions/680241/resetting-a-multi-stage-form-with-jquery
            $form.find('input:text, input:password, input:file, select, textarea').val('');
            $form.find('option[value=""]').remove();

            $form.find('input:radio, input:checkbox')
              .removeAttr('checked')
              .removeAttr('selected');

            $form.find('select').append(new Option('-', '', true, true));
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

        // for handling click of the delete button
        $('#edit').on('click', function() {
                $('#form').attr("action", '/');
                $("#form").attr("method", 'post');
            }
        );

        // for handling click of the delete button
        $('#skip').on('click', function() {
                $("#form").find('input:hidden').val('');
                $("#form").submit();
            }
        );

        // for handling click of the clear button
        $('#clear').on('click', function() {
                resetForm($('#form'));
            }
        );      
    </script>

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
    <!-- script src="/mojo/jquery/jquery.js"></script -->
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.0/jquery.min.js"></script>
    <!-- Latest compiled and minified JavaScript -->
    <script src="https://netdna.bootstrapcdn.com/bootstrap/3.1.1/js/bootstrap.min.js"></script>

    %= include 'javascript'
    
  </body>
</html>