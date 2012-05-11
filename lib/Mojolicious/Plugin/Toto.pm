=head1 NAME

Mojolicious::Plugin::Toto - A simple tab and object based site structure

=head1 SYNOPSIS

 use Mojolicious::Lite;

 get '/my/url/to/list/beers' => sub {
      shift->render_text("Here is a page for listing beers.");
 } => "beer/list";

 get '/beer/create' => sub {
    shift->render_text("Here is a page to create a beer.");
 } => "beer/create";

 get '/pub/view' => { controller => 'Pub', action => 'view' } => 'pub/view';

 plugin 'toto' =>
    menu => [
        beer    => { one  => [qw/view edit pictures notes/],
                     many => [qw/list create search browse/] },
        brewery => { one  => [qw/view edit directions beers info/],
                     many => [qw/phonelist mailing_list/] },
        pub     => { one  => [qw/view info comments hours/],
                     many => [qw/search map/] },

      # object  => { one => ....tabs....
      #             many => ...more tabs...

    ],
 ;

 app->start

 ./Beer daemon

=head1 DESCRIPTION

This plugin provides a navigational structure and a default set
of routes for a Mojolicious or Mojolicious::Lite app.

It extends the idea of BREAD or CRUD -- in a BREAD application,
browse and add are operations on zero or many objects, while
edit, add, and delete are operations on one object.

Toto groups all pages into these two categories : either they act on
zero or many objects, or they act on one object.

One set of tabs provides a way to change between types of objects.
Another set of tabs is specific to the type of object selected.

The second set of tabs varies depending on whether or not
an object (instance) has been selected.

=head1 HOW DOES IT WORK

After loading the toto plugin, the default layout is set to 'toto'.
The name of the each route is expected to be of the form <object>/<tab>.
where <object> refers to an object in the menu structure, and <tab>
is a tab for that object.

Defaults routes are generated for every combination of object + associated tab.

Templates in the directory templates/<object>/<tab>.html.ep will be used when
they exist.

The stash values "object" and "tab" are set for each auto-generated route.
Also "noun" is set as an alias to "object".

Styling is done with twitter's bootstrap <http://twitter.github.com/bootstrap>,
and a version of bootstrap is included in this distribution.

If a route should be outside of the toto framework, just set the layout, e.g.

    get '/no/toto' => { layout => 'default' } => ...

To route to another controller

    get '/some/route' => { controller => "Foo", action => "bar" } ...

=head1 TODO

Document these helpers, which are added automatically :

toto_config, model_class, objects, current_object, current_tab, current_instance


=head1 SEE ALSO

http://www.beer.dotcloud.com

=cut

package Mojolicious::Plugin::Toto;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream qw/b/;
use File::Basename 'dirname';
use File::Spec::Functions 'catdir';
use Mojolicious::Plugin::Toto::Model;
use Cwd qw/abs_path/;

use strict;
use warnings;

our $VERSION = 0.09;

sub _render_static {
    my $c = shift;
    my $what = shift;
    $c->render_static($what);
}

sub _cando {
    my ($namespace,$controller,$action) = @_;
    my $package = join '::', $namespace, b($controller)->camelize;
    return $package->can($action) ? 1 : 0;
}

sub _to_noun {
    my $word = shift;
    $word =~ s/_/ /g;
    $word;
}

sub register {
    my ($self, $app, $conf) = @_;

    my @menu = @{ $conf->{menu} || [] };
    my $prefix = $conf->{prefix} || '';
    my %menu = @menu;

    my $base = catdir(abs_path(dirname(__FILE__)), qw/Toto Assets/);
    my $default_path = catdir($base,'templates');
    push @{$app->renderer->paths}, catdir($base, 'templates');
    push @{$app->static->paths},   catdir($base, 'public');
    $app->defaults(layout => "toto", toto_prefix => $prefix);

    for my $object (keys %menu) {

        my $first;
        for my $tab (@{ $menu{$object}{many} || []}) {
            $first ||= $tab;
            my @found_object_template = map { glob "$_/$object/$tab.*" } @{ $app->renderer->paths };
            my @found_template = map { glob "$_/$tab.*" } @{ $app->renderer->paths };
            my $found_controller = _cando($app->routes->namespace,$object,$tab);
            $app->log->debug("Adding route for $prefix/$object/$tab");
            $app->routes->any(
                "$prefix/$object/$tab" => {
                    template => ( 0 + @found_object_template ? "$object/$tab"
                        : 0 + @found_template ? $tab
                        :                       "plural" ),
                    object     => $object,
                    noun       => $object,
                    tab        => $tab,
                    ( !$found_controller ?  () : (
                      controller => $object,
                      action     => $tab,
                    ))
                  } => "$object/$tab"
            );
        }
        my $first_action = $first;
        $app->routes->get(
            "$prefix/$object" => sub {
                my $c = shift;
                $c->redirect_to("$prefix/$object/$first_action");
              } => "$object"
        );
        $first = undef;
        for my $tab (@{ $menu{$object}{one} || [] }) {
            $first ||= $tab;
            my @found_object_template = map { glob "$_/$object/$tab.*" } @{ $app->renderer->paths };
            my @found_template = map { glob "$_/$tab.*" } @{ $app->renderer->paths };
            my $found_controller = _cando($app->routes->namespace,$object,$tab);
            $app->log->debug("Adding route for $prefix/$object/$tab/*key");
            $app->log->debug("Found controller class for $object/$tab/key") if $found_controller;
            $app->log->debug("Found template for $object/$tab/key") if @found_template || @found_object_template;
            $app->routes->under("$prefix/$object/$tab/(*key)"  =>
                    sub {
                        my $c = shift;
                        $c->stash(object => $object);
                        $c->stash(noun => _to_noun($object));
                        $c->stash(tab => $tab);
                        my $key = lc $c->stash('key');
                        my @found_instance_template = map { glob "$_/$object/$key/$tab.*" } @{ $app->renderer->paths };
                        $c->stash(
                            template => (
                                  0 + @found_instance_template ? "$object/$key/$tab"
                                : 0 + @found_object_template ? "$object/$tab"
                                : 0 + @found_template        ? $tab
                                : "single"
                            )
                        );
                        my $instance = $c->current_instance;
                        $c->stash( instance => $instance );
                        $c->stash( $object  => $instance );
                        1;
                      }
                    )->any->to("$object#$tab") # TODO only if $found_controller, else use template.
                     ->name("$object/$tab");
        }
        my $first_key = $first;
        $app->routes->get(
            "$prefix/$object/default/(*key)" => sub {
                my $c = shift;
                my $key = $c->stash("key");
                $c->redirect_to("$object/$first_key/$key");
              } => "$object/default"
        );

    }
    my @objects = grep !ref($_), @menu;
    die "no objects" unless @objects;
    my $first_object = $objects[0];
    $app->routes->get("$prefix/" => sub { shift->redirect_to($first_object) } );

    for ($app) {
        $_->helper( toto_config => sub { $conf } );
        $_->helper( model_class => sub {
                my $c = shift;
                if (my $ns = $conf->{model_namespace}) {
                    return join '::', $ns, b($c->current_object)->camelize;
                }
                $conf->{model_class} || "Mojolicious::Plugin::Toto::Model"
             }
         );
        $_->helper( objects => sub { @objects } );
        $_->helper(
            tabs => sub {
                my $c    = shift;
                my $for  = shift || $c->current_object;
                my $mode = defined( $c->stash("key") ) ? "one" : "many";
                @{ $menu{$for}{$mode} || [] };
            }
        );
        $_->helper( current_object => sub {
                my $c = shift;
                $c->stash('object') || [ split '\/', $c->current_route ]->[0]
            } );
        $_->helper( current_tab => sub {
                my $c = shift;
                $c->stash('tab') || [ split '\/', $c->current_route ]->[1]
            } );
        $_->helper( current_instance => sub {
                my $c = shift;
                my $key = $c->stash("key") || [ split '\/', $c->current_route ]->[2];
                return $c->model_class->new(key => $key);
            } );
        $_->helper( printable => sub {
                my $c = shift;
                my $what = shift;
                $what =~ s/_/ /g;
                $what } );
    }

    $self;
}

1;

__DATA__

@@ layouts/toto.html.ep
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">
<html>
<head>
<title><%= title %></title>
%= base_tag
%= stylesheet "bootstrap/css/bootstrap.min.css";
<style>
pre.toto_code {
    float:right;
    right:10%;
    padding:5px;
    border:1px grey dashed;
    font-family:monospace;
    position:absolute;
    }
</style>
</head>
<body>
<div class="container">
<div class="row">
<div class="span1">&nbsp;</div>
<div class="span11">
    <ul class="nav nav-tabs">
% for my $c (objects) {
        <li <%== $c eq $object ? q[ class="active"] : "" =%>>
            <%= link_to "$toto_prefix/$c" => begin =%><%= $c =%><%= end =%>
        </li>
% }
    </ul>
</div>
</div>
    <div class="tabbable tabs-left">
% if (stash 'key') {
%= include 'top_tabs_single';
% } else {
%= include 'top_tabs_plural';
% }
         <div class="tab-content" style='width:auto;'>
         <%= content =%>
         </div>
    </div>
</div>
</html>

