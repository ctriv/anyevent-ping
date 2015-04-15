package AnyEvent::Ping::DGRAM;

use strict;
use warnings;
use base 'AnyEvent::Ping';

use Socket qw/SOCK_DGRAM/;

sub _create_socket {
    my $self = shift;

    IO::Socket::INET->new(
        Proto    => 'icmp',
        Type     => SOCK_DGRAM,
        Blocking => 0
    ) or Carp::croak "Unable to create icmp socket : $!";
}

sub _process_chunk_to_request {
    my ($self, $chunk) = @_;

    my $icmp_msg = $^O eq 'linux' ? $chunk : substr($chunk, 20);

    my ($type, $identifier, $sequence, $data);

    $type = unpack 'c', $icmp_msg;

    if ($type == $AnyEvent::Ping::ICMP_ECHOREPLY) {
        ($type, $identifier, $sequence, $data) =
          (unpack $AnyEvent::Ping::ICMP_PING, $icmp_msg)[0, 3, 4, 5];
    }
    elsif ($type == $AnyEvent::Ping::ICMP_DEST_UNREACH || $type == $AnyEvent::Ping::ICMP_TIME_EXCEEDED) {
        ($identifier, $sequence) = unpack('nn', substr($chunk, 52));
    }
    else {

        # Don't mind
        return;
    }

    # Find our task
    my $request = List::Util::first { $data eq $_->{data} } @{$self->{_tasks}};

    return unless $request;

    # Is it response to our latest message?
    return unless $sequence == @{$request->{results}} + 1;
    
    return ($request, $type, $data);
}


1;
