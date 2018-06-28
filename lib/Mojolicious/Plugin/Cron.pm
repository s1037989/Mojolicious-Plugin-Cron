package Mojolicious::Plugin::Cron;
use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = '0.01';

use Mojo::IOLoop;

use Time::Piece;

sub register {
  my ($self, $app, $config) = @_;

  return unless ref $config eq 'ARRAY' && @$config;

  $app->hook(before_server_start => sub {
    my $server = shift;
    Mojo::IOLoop->subprocess->run(
      sub {
        my $subprocess = shift;
        $0 = "cron";
        warn "Starting cron...\n";
        $subprocess->ioloop->recurring(15 => sub {
          local @_ = @$config;
          while ( my ($when, $command, $name) = (shift, shift, shift) ) {
            last unless $when && $command;
            my ($m, $h, $dom, $mon, $dow) = split /\s+/, $when;
            warn "Running cron in subprocess";
            $subprocess->ioloop->subprocess->run(
              sub {
                $0 = "$name";
                return $command->(shift);
              },
              sub {
                my ($subprocess, $err, @results) = @_;
                my $pid = $subprocess->pid;
                $app->log->error("Cron $pid exited: $err") and return if $err;
                $app->log->info("Cron $pid exited: @results");
              }
            );
          }
        });
        $server->on(finish => sub {
          warn "Exiting cron...\n";
          $subprocess->ioloop->stop if $subprocess->ioloop->is_running;
        });
        $subprocess->ioloop->start unless $subprocess->ioloop->is_running;
      },
      sub {
        warn "Exiting cron . . .\n";
      }
    );
  });
}

1;
__END__

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Cron - Mojolicious Plugin

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('Cron');

  # Mojolicious::Lite
  plugin 'Cron';

=head1 DESCRIPTION

L<Mojolicious::Plugin::Cron> is a L<Mojolicious> plugin.

=head1 METHODS

L<Mojolicious::Plugin::Cron> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
