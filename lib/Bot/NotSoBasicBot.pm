package Bot::NotSoBasicBot;
use base qw( Bot::BasicBot );

use warnings;
use strict;

use Config::Auto;
use POE;
use Event::Schedule;


=head1 NAME

Bot::NotSoBasicBot - Builts on Bot::BasicBot, adding a little extra functionality for convenience.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

C<Bot::NotSoBasicBot> adds some functionality and convenience to the already pretty fantastic C<Bot::BasicBot>.
Chief among those new features is the ability to set mode on channels, so you can make your own modbots, like
C<Bot::Roberts>, which is itself derived from C<Bot::NotSoBasicBot>.  It can also start from a configuration
file, allowing you to write bot scripts that need no modification at all to run in different environments.

Its use is even simpler than C<Bot::BasicBot>.

    use Bot::NotSoBasicBot;

    my $bot = Bot::NotSoBasicBot->new("my.conf");
    $bot->run();

Now, C<Bot::NotSoBasicBot> alone will not do very much at all of any interest.  You'll want to subclass it.
For better functionality right out of the box, see C<Bot::Listener> and C<Bot::Roberts> in this distribution.

=head1 FUNCTIONS

=head2 new ($configfile) (or nothing)

C<Bot::NotSoBasicBot> uses C<Config::Auto> to parse a configuration file.  If you don't give new() a filename,
it will let C<Config::Auto> figure it out for you.  This might work, or might have hilarious consequences.

Once the configuration is read, the C<munge_config> class function is called so you can preprocess your
configuration before it's used to initiate the bot.  This means that if you need to do something funky
to derive C<nick>, C<server>, and/or C<channels>, do it there.

=cut

sub new {
   my ($class, $configfile) = @_;

   my $config = Config::Auto::parse ($configfile);
   if (ref ($config->{channels}) eq '') {
      $config->{channels} = [ $config->{channels} ];
   }
   $class->munge_config ($config);
   #print "nick: $config->{nick}\n";
   my $self = $class->SUPER::new(
      server => $config->{server},
      nick => $config->{nick},
      channels => $config->{channels},
      event_queue => Event::Schedule->new()
   );
   $self->{config} = $config;

   #$self->{nick} = $self->{config}->{nick};
   return $self;
}

=head2 munge_config ($config) CLASS METHOD

The C<munge_config> method is called I<before> the object is initialized, so it's a class method, not an
object method.  This may be confusing.

=cut

sub munge_config {
   my ($class, $config) = @_;
}

=head2 logline ($channel, $what_said)

The C<logline> function provides a central transcripting location.  Debugging logs can easily be kept
separate from transcripts of the channels your bot is listening to.  You'll probably want to override it,
as its standard implementation just uses BasicBot's log function, which writes to stderr.

=cut

sub logline {
   my ($self, $channel, $what) = @_;

   $self->log ("[] $channel $what") unless $channel eq 'msg';
}

=head2 announce ($channel, $what_to_say)

The C<announce> function says something on the channel listed, and simultaneously logs it to the transcript.

=cut
sub announce {
   my ($self, $channel, $what) = @_;

   $self->say ( channel => $channel, body => $what);
   $self->logline ($channel, "<" . $self->{nick} . "> " . $what);
}

=head2 say_discreetly ($channel, $who, $what_to_say)

The C<say_discreetly> function says something to a user by PM if given a user; otherwise, announces it on the channel.

=cut
sub say_discreetly {
   my ($self, $channel, $who, $what) = @_;
   if ($who) {
      $self->say (who=>$who, channel=>'msg', body=>$what);
   } else {
      $self->announce ($channel, $what);
   }
}

=head2 reply ($channel, $mode, $who, $what_to_say)

The C<reply> function takes the modes generated by C<said> below and either announces a reply or says it discreetly.

=cut

sub reply {
   my ($self, $channel, $mode, $who, $what) = @_;

   if ($mode eq 'addressed') {
      $self->announce ($channel, $what);
   } elsif ($mode eq 'private') {
      $self->say_discreetly ($channel, $who, $what);
   }
}

=head2 said ($message)

The C<said> function is just the usual C<Bot::BasicBot> hook for incoming messages.  The default implementation logs
the transcript, then calls a C<respond> hook unique to C<Bot::NotSoBasicBot> after organizing the input a little
for you.

Before logging the transcript, it calls a "remember" function that can be overridden if the bot needs a memory of things
that have been said.  Only things said in public are remembered.

=cut
sub said {
   my ($self, $message) = @_;

   $self->remember ($message->{channel}, $message->{who}, $message->{body}) unless $message->{channel} eq 'msg';

   $self->logline ($message->{channel}, "<" . $message->{who} . "> " . $message->{raw_body});

   $message->{address} = '' unless defined $message->{address};

   my $mode = 'general';
   $mode = 'addressed' if $message->{address} eq $self->{nick};
   $mode = 'private' if $message->{channel} eq 'msg';

   $self->respond ($message->{channel}, $mode, $message->{who}, $message);
}

=head2 remember ($channel, $who, $what)

The C<remember> hook is called to allow the bot to keep track of things people have said.  Since most bots don't need
this, the default does nothing and you can usually ignore it.

=cut
sub remember { }

=head2 emoted ($message)

The C<emoted> function is the C<Bot::BasicBot> hook for incoming emoted messages.  The default logs the
transcript in normal emote format, then calls C<respond> with mode 'emoted'.

=cut

sub emoted {
   my ($self, $message) = @_;

   $self->logline($message->{channel}, " * " . $message->{who} . " " . $message->{body});
   $self->respond ($message->{channel}, 'emoted', $message->{who}, $message);
}


=head2 respond ($channel, $mode, $who, $message)

The C<respond> function is a hook you can override to respond to things said to the bot.

$mode takes values 'general' for things said on the channel, 'emoted' for things emoted on the
channel (if you care), 'addressed' for things said to the bot on the channel with "Nick:" addressing,
and 'private' for things addressed to the bot on PM.

=cut
sub respond { }

=head2 users ($channel)

The C<users> function calls C<Bot::BasicBot>'s C<channel_data> function to retrieve the list
of users on the channel.  If called in list context, it returns the list of users; if called in scalar
context, a hashref mapping user names onto hashrefs of 'voice' and 'op' flags for each user (i.e.
the same thing channel_data returns).

This allows us to say e.g. C<foreach my $u in $self->users()>.  Isn't that easy?

=cut

sub users {
   my ($self, $channel) = @_;

   my $users = $self->channel_data ($channel);
   if (defined $self->{building_channel_data}->{$channel}) {
      $users = $self->{building_channel_data}->{$channel};
   }
   return sort(keys(%$users)) if wantarray();
   return $users;
}

=head2 mode ($modestrings)

The C<mode> function performs a mode command on the channel of your choice.  No matter how many strings you
give it, it will just join them all together to form a mode command.

=cut

sub mode {
   my $self = shift;
   my $mode = join ' ', @_;

   $poe_kernel->post ($self->{IRCNAME} => mode => $mode);
}

=head2 join ($channel)

The C<join> function attempts to join a channel.  Note that this won't affect $self->{config}->{channels}.

=cut

sub join {
   my ($self, $channel) = @_;

   $poe_kernel->post ($self->{IRCNAME} => join => $channel);
}

=head3 tick()

The default C<tick> handler makes sure it's called every second to service the event queue.

=cut
sub tick {
   my ($self) = @_;
   $self->{event_queue}->tick();
   return 1;
}

=head3 schedule($time, $event)

C<Bot::NotSoBasicBot> uses L<Event::Schedule> to maintain a queue of events to be executed
at specific times.  This allows us to schedule something to be done a minute after a given
response, for instance, without worrying about how it will work.

C<$time> is the number of seconds to wait until executing the event;
C<$event> is a coderef to a (usually anonymous) procedure to be called with no parameters.
To call something I<with> parameters, enclose it in an anonymous procedure to form a closure,
e.g.

   $self->schedule (60, sub { $self->announce ($channel, "Did you forget about me?") });

=cut

sub schedule {
   my ($self, $time, $event) = @_;
   $self->{event_queue}->add ($time, $event);
}



=head1 AUTHOR

Michael Roberts, C<< <michael at vivtek.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-bot-notsobasicbot at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Bot-NotSoBasicBot>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Bot::NotSoBasicBot


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Bot-NotSoBasicBot>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Bot-NotSoBasicBot>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Bot-NotSoBasicBot>

=item * Search CPAN

L<http://search.cpan.org/dist/Bot-NotSoBasicBot/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2010 Michael Roberts, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Bot::NotSoBasicBot