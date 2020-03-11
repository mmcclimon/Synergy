use v5.24.0;
package Synergy::Listener::Declarative;
use Moose;
use Moose::Exporter;

use experimental qw(postderef signatures);
use Carp ();
use Synergy::Listener;

Moose::Exporter->setup_import_methods(
  with_meta => [ 'listener' ],
);

my %COMMANDOS;

sub listener ($meta, $name, %spec) {
  my $class = $meta->name;
  my $commando = $COMMANDOS{$class};

  if (! $commando) {
    # This is the first time we've seen our class...add the attribute
    $commando = $COMMANDOS{$class} = Synergy::Listener::Declarative->new;

    $meta->add_attribute(
      commando => (
        reader => 'commando',
        init_arg => undef,
        lazy => 1,
        default => sub { $commando },
      ),
    );
  }

  $commando->add_listener($name, \%spec);
}

has _listener_specs => (
  is => 'ro',
  isa => 'HashRef',
  traits => ['Hash'],
  default => sub { {} },
  handles => {
    has_listener_named => 'exists',
    listener_named     => 'get',
    set_listener       => 'set',
    listener_specs     => 'values',
  },
);

sub add_listener ($self, $name, $spec) {
  die "listener $name registered more than once"
    if $self->has_listener_named($name);

  # build a predicate
  my $predicate = delete $spec->{predicate};

  my $require_targeted = $spec->{always} ? 0 : 1;

  my @matchers;
  push @matchers, $spec->{match} if $spec->{match};

  # For all of our names, we'll match our name at the beginning of the command
  my @names = ($name);
  push @names, $spec->{aliases}->@* if $spec->{aliases};

  push @matchers, qr{\A\Q$_\E\b} for @names;

  if (! $predicate) {
    my $require_targeted = $spec->{always} ? 0 : 1;

    $predicate = sub ($listener, $event) {
      return 0 if $require_targeted && ! $event->was_targeted;

      for my $re (@matchers) {
        return 1 if $event->text =~ /$re/i;
      }

      return 0;
    };
  }

  $self->set_listener($name, {
    name => $name,
    method => delete $spec->{handler},
    predicate => $predicate,
    %$spec,
  });
}

no Moose;
1;
