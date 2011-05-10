=head1 NAME

Mojolicious::Plugin::Toto - the toto navigational structure

=head1 DESCRIPTION

package Mojolicious::Plugin::Toto;

=cut

package Mojolicious::Plugin::Toto;
use File::Basename qw/basename/;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream qw/b/;

sub register {
    my $self     = shift;
    my $app      = shift;
    my $location = ( !ref $_[0] ? shift : "/toto" );
    my $conf     = shift;
    my %conf     = @$conf;

    $app->routes->route($location)->detour(app => Toto::app());

    my @nouns = grep !ref($_), @$conf;
    for ($app, Toto::app()) {
        $_->helper( toto_config => sub { @$conf } );
        $_->helper( app_name    => sub { basename($ENV{MOJO_EXE}) });
        $_->helper( nouns       => sub { @nouns } );
        $_->helper( many        => sub { @{ $conf{ $_[1] }{many} } } );
        $_->helper( one         => sub { @{ $conf{ $_[1] }{one} } } );
    }
}

package Toto::Controller;
use Mojo::Base 'Mojolicious::Controller';

sub default {
    my $c = shift;
    $c->render(template => "plural");
}

package Toto;
use Mojolicious::Lite;
use Mojo::ByteStream qw/b/;

get '/' => { layout => "menu", controller => 'top' } => 'toto';

get '/:controller/:action' => {
    action    => "default",
    namespace => "Toto::Controller",
    layout    => "menu_plurals"
  } => sub {
    my $c = shift;
    my ( $action, $controller ) = ( $c->stash("action"), $c->stash("controller") );
    if ($c->stash("action") eq 'default') {
        my $first = [ $c->many($controller) ]->[0];
        return $c->redirect_to( "plural" => action => $first, controller => $controller )
    }
    my $class = join '::', $c->stash("namespace"), b($controller)->camelize;
    $c->render(class => $class, template => "plural") unless $class->can($action);
  } => 'plural';

get '/:controller/:action/(*key)' => {
    action => "default",
    namespace => "Toto::Controller",
    layout => "menu_single"
} => sub {
    my $c = shift;
    my ( $action, $controller, $key ) =
      ( $c->stash("action"), $c->stash("controller"), $c->stash("key") );
    if ($c->stash("action") eq 'default') {
        my $first = [ $c->one($controller) ]->[0];
        return $c->redirect_to( "single" => action => $first, controller => $controller, key => $key )
    }
    my $class = join '::', $c->stash("namespace"), b($controller)->camelize;
    $c->render(class => $class, template => "single") unless $class->can($action);
} => 'single';

1;
__DATA__
@@ layouts/menu.html.ep
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">
<html>
<head>
<title><%= title %></title>
%= stylesheet '/toto.css';
</head>
<body>
<div id="left-sidebar">
<ul class="left-menu">
% for my $noun (nouns) {
<li <%== $noun eq $controller ? q[ class="selected"] : "" =%>>
%= link_to url_for("plural", { controller => $noun }) => begin
<%= $noun =%>s
%= end
% }
</ul>
</div>
<div id="content">
%= content "second_header";
%= content
</div>
</body>
</html>

@@ layouts/menu_plurals.html.ep
% layout 'menu';
%= content second_header => begin
<div id='header'>
<span class='home'>
%= link_to 'Toto' => 'toto';
</span>
% for my $a (many($controller)) {
% $class = ($action eq $a) ? "selected" : "unselected";
%= link_to url_for("plural", { controller => $controller, action => $a }) => class => $class => begin
%= $a
%= end
% }
</div>
% end

@@ layouts/menu_single.html.ep
% layout 'menu';
%= content second_header => begin
<div>
% for my $action (one($controller)) {
%= link_to url_for("single", { controller => $controller, action => $action, key => $key }) => begin
%= $action
%= end
% }
</div>
% end

@@ single.html.ep
This is the page for <%= $action %> for
<%= $controller %> <%= $key %>.

@@ plural.html.ep
<hr>
your page to <%= $action %> <%= $controller %>s goes here<br>
(add <%= $class %>::<%= $action %>)<br>
% for (1..10) {
%= link_to 'single', { controller => $controller, key => $_ } => begin
<%= $controller %> <%= $_ %><br>
%= end
% }
<hr>

@@ toto.html.ep
<center>
<br>
Welcome to <%= app_name %><br>
Please choose a menu item.
</center>

@@ toto.css
body{
  margin:0;
  padding:30px 0 0 110px;
 }
div#header{
 position:absolute;
 top:0;
 left:0%;
 width:90%;
 height:30px;
 background-color:#aff;
 padding-left:110px;
 z-index:-1;
}
div#left-sidebar{
 position:absolute;
 top:0;
 left:0;
 width:100px;
 height:100%;
 background-color:#aaf;
 padding-top:30px;
}
@media screen{
 body>div#header{
  position:fixed;
 }
 body>div#left-sidebar{
  height:100%;
  position:fixed;
 }
}
* html body{
 overflow:hidden;
} 
* html div#content{
 height:100%;
 overflow:auto;
}
ul.left-menu {
    margin-left:0px;
    padding-left:0px;
    }
ul.left-menu li {
    list-style-type:none;
    list-style-position:outside;
    padding-left:3px;
    width:100%;
}
ul.left-menu li.selected {
    background-color:white;
}
ul.left-menu a {
    color:black;
    text-decoration:none;
}
.home {
    float:right;
    display:inline;
    }
