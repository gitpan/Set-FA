###########################################################################
# $Id: Element.pm,v 1.2 2002/03/22 05:33:21 wendigo Exp $
###########################################################################
#
# Set::FA::Element
#
# RCS Revision: $Revision: 1.2 $
# Date: $Date: 2002/03/22 05:33:21 $
#
# Copyright (c) 2002 Mark Rogaski, mrogaski@cpan.org; all rights reserved.
#
# See the README file included with the
# distribution for license information.
#
# $Log: Element.pm,v $
# Revision 1.2  2002/03/22 05:33:21  wendigo
# Added unified transition rule representation
# Rewrote clone using a recursive deep copy
#
# Revision 1.2  2002/03/17 16:35:41  wendigo
# Added id, data, and clone.
#
# Revision 1.1  2002/03/17 04:20:57  wendigo
# Initial revision
#
#
###########################################################################

package Set::FA::Element;

use 5.006;
use strict;
use warnings;
use AutoLoader qw(AUTOLOAD);
use Log::Agent;

our $VERSION = sprintf "%d.%01d%02d", (split /\D+/, '$Name: beta0_1_1 $')[1..3];

#
# new -- object constructor
#
sub new {
    my($class, %prop) = @_;
    my $self = {
        current => '',
        id      => '',
        data    => '',
        state   => {},
        start   => '',
        trans   => {},
        action  => {},
    };
    bless $self, $class;
    logdbg 'debug', "building FA element";

    #
    # build FA states
    #
    if (ref $prop{states} eq 'ARRAY') {

        $self->{start} = $prop{states}->[0];    # set the start state
        logdbg 'debug', "setting start state to $self->{start}";

        foreach my $state (@{$prop{states}}) {
            # the value indexed by the state is a flag
            # indicating whether the state is an accept state
            $self->{state}{$state} = 0;
            logdbg 'debug', "added state $state";
        }

        if (ref $prop{accept} eq 'ARRAY') {
            foreach my $state (@{$prop{accept}}) {
                # look for typos
                logcroak "unknown state $state"
                        unless exists $self->{state}{$state};
                $self->{state}{$state} = 1;
                logdbg 'debug', "marking state $state as final";
            }
        }

    } else {
    
        logcroak "no states defined for FA";

    }

    #
    # build transition table
    #
    if (ref $prop{transitions} eq 'ARRAY') {
        foreach my $trans (@{$prop{transitions}}) {
            logcroak "invalid transition definition"
                    unless ref $trans eq 'ARRAY';
            my($curr, $rule, $next) = @{$trans};

            # look for invalid states
            logcroak "unknown state $curr" unless exists $self->{state}{$curr};

            # encapsulate regexs in functions
            unless (ref $rule eq 'CODE') {
                my $regex = qr{$rule}; # precompile regex
                $rule = sub {
                    my($obj, $input) = @_;
                    if ($input =~ /^$regex(.*)/) {
                        return $1;
                    }
                    return;
                };
            }

            push(@{$self->{trans}{$curr}}, [$rule, $next]);
            logdbg 'debug', "added transition [ $curr, $rule, $next ]";

        }
    }

    #
    # build action table
    #
    if (ref $prop{actions} eq 'HASH') {
        foreach my $state (keys %{$prop{actions}}) {
            foreach my $trigger (keys %{$prop{actions}->{$state}}) {
                $self->set_action($state, $trigger,
                        $prop{actions}->{$state}{$trigger});
            }
        }
    }

    #
    # add scalar fields
    #
    $self->id($prop{id});
    $self->data($prop{data});

    #
    # initialize FA
    #
    $self->reset;

    return $self; 
}

#
# set_action -- insert an action coderef
#
sub set_action {
    my($self, $state, $trigger, $action) = @_;
    
    # check for valid identifiers
    logcroak "unknown state: $state" unless $self->state($state);
    logcroak "unknown trigger event: $trigger"
            unless $trigger =~ /^(entry|exit)$/;

    logdbg 'debug', "adding action for $state.$trigger";
    $self->{action}{$state}{$trigger} = $action;
}

#
# set_state -- execute state transitions
#
sub set_state {
    my($self, $next) = @_;
    my $curr = $self->state;

    return if $curr eq $next;

    if (exists $self->{action}{$curr}{exit}) {
        logdbg 'debug', "executing exit action for state $curr";
        $self->{action}{$curr}{exit}->($self);
    }

    $self->{current} = $next;

    if (exists $self->{action}{$next}{entry}) {
        logdbg 'debug', "executing entry action for state $next";
        $self->{action}{$next}{entry}->($self);
    }

}

#
# accept -- scan input for acceptability
#
sub accept {
    my($self, $str) = @_;
    return $self->final($self->advance($str));
}

#
# advance -- exhaustively process input
#
sub advance {
    my($self, $str) = @_;
    while ($str) {
        my $new = $self->step($str);
        logdbg 'debug', "input not being consumed, possible infinite loop"
                if length($new) >= length($str);
        $str = $new;
    }
    return $self->state;
}

#
# step -- process a single chunk of input and execute transition
#
sub step {
    my($self, $input) = @_;
    my $state = $self->state;

    foreach my $elem (@{$self->{trans}{$state}}) {
        my($rule, $next) = @{$elem};
        my $output = $rule->($self, $input);
        if (defined $output) {
            logdbg 'debug', "transition to $next on input: $input";
            $self->set_state($next);
            return $output;
        }
    }

    logdbg 'debug', "no transition on input: $input";
    return $input;
}

#
# id -- accessor/mutator for id field
#
sub id {
    my($self, $id) = @_;
    if (defined $id) {
        $self->{id} = $id;
    }
    return $self->{id};
}

#
# data -- accessor/mutator for data field
#
sub data {
    my($self, $data) = @_;
    if (defined $data) {
        $self->{data} = $data;
    }
    return $self->{data};
}

#
# final -- test for acceptability of a state
#
sub final {
    my $self  = shift;
    my $state = shift || $self->state;
    return $self->{state}{$state};
}

#
# reset -- return FA to starting values
#
sub reset {
    my($self) = @_;
    return $self->{current} = $self->{start};
}

#
# state -- accessor for current state
#
sub state {
    my($self, $state) = @_;
    if (defined $state) {
        return exists $self->{state}{$state};
    } else {
        return $self->{current};
    }
}

1;
__END__

=head1 NAME

Set::FA::Element - Discrete finite automaton element for Set::FA

=head1 SYNOPSIS

  use Set::FA::Element;

  my $fa = Set::FA::Element->new(
      id           => "oddmachine",
      data         => \$data,
      states       => [ qw( none even odd ) ],
      accept       => [ 'odd' ],
      transitions  => [
          [ 'none', qr/./, 'odd'  ],
          [ 'odd' , qr/./, 'even' ],
          [ 'even', qr/./, 'odd'  ]
      ],
      actions      => {
          even => { exit  => \&foo },
          odd  => { entry => \&bar }
      }
  );

  #
  # perform multiple transitions on input
  #
  foreach $str (@inputs) {
      if ($fa->accept($str)) {
          print "Accepted $str\n";
      } else {
          print "Rejected $str\n";
      }
      $fa->reset;
  }

  #
  # step through transitions 
  #
  while ($input) {
      $input = $fa->step($input);
  }
  
  if ($fa->final) {
      print "Accept\n";
  } else {
      print "Reject\n";
  }

=head1 DESCRIPTION

This module provides a simple finite automaton object.  The FA
object is capable of deterministic operation either by processing a scalar
value or list of scalars, or by stepping through execution a single transition
at a time.

=head1 CONSTRUCTOR

=head2 B<new PROPERTIES>

A new FA object is constructed.  PROPERTIES is a hash that B<must>
contain the following elements:

=over 16

=item states

The value associated with this key must be a reference to an array of
scalar values representing the names of the states in the FA.  At least
one state must be defined.  The first element is distinguished as the start
state.

=back

PROPERTIES may also contain the following optional entries:

=over 16

=item accept

This entry is a reference to a list of state names which are considered
final states.  

=item actions

This element is a reference to a hash indexed by valid state names,
containing references to hashes that may contain the following entries:

=over 8

=item entry

This contains a reference to a subroutine that is executed when the
corresponding state is entered.  The subroutine is called with a reference
to the object as an argument.

=item exit

This contains a reference to a subroutine that is executed when the
corresponding state is exited.  The subroutine is called with a reference
to the object as an argument.

=back

=item data

A scalar data payload field for the FA.  This field has little use outside
of the Set::FA environment.

=item id

A scalar identifier for the FA element.  This field has little use outside
of the Set::FA environment.

=item transitions

This element is a value containing a reference to an list of 
3-tuple lists of the form C<[ CURRENT, PATTERN, NEXT ]>.

=over 8

=item CURRENT

This is the name of the current state.  The rule will only be applied when the
FA is in this state.

=item PATTERN

This is either a regular expression or a code reference.  If a code reference
is supplied, the subroutine is supplied a reference to the object and 
the input scalar as arguments and
should return the unmatched portion of the input on success or undef on
failure.

=item NEXT

This is the state to which the FA transitions if PATTERN matches.

=back

=back

B<Note:> it is very easy to construct a FA that doesn't terminate.  See
L<NOTES/Infinite Loops> for a discussion of how to avoid infinite executuion.

=head1 METHODS

=head2 B<accept INPUT>

Processes the INPUT and returns true if the FA is in an accept
state when the entire input has been consumed, false otherwise.

=head2 B<advance INPUT>

Processes the INPUT and returns the state that the FA is in
after the input has been consumed.

=head2 B<clone>

Returns a deep copy of the FA element or false on failure.

=head2 B<data [ SCALAR ]>

If no argument is given, the current value of the data field is given.  If 
the SCALAR argument is given, it is assigned to the data field.

=head2 B<final [ STATE ]>

If no argument is given, returns true if the FA is in an accept state,
false otherwise.  If STATE is supplied as an argument; returns true if
STATE is defined as an accept state, false otherwise.

=head2 B<id [ SCALAR ]>

If no argument is given, the current value of the id field is given.  If 
the SCALAR argument is given, it is assigned to the id field.

=head2 B<reset>

Resets the state to the initial state.

=head2 B<state [ STATE ]>

If no argument is given, returns the current state of the FA.  If STATE is
supplied, returns true if the state is defined for the FA, false otherwise.

=head2 B<step INPUT>

Processes the INPUT for a single transition, returning 
the unconsumed portion of the input.

=head1 EXPORT

None by default.

=head1 NOTES

=head2 Infinite Loops

Infinite loops are an unfortunate side-effect of any useful programming
language.  Certain enhancements to the standard concept of FAs that have
been included here make it relatively easy to shoot yourself in the foot.

First, any input for which there is no transition defined is treated as a
transition to the current state.  However, since variable length patterns
are allowed, no input is consumed.  Those familiar with theoretical computer
science should recognize "no input is consumed" as a big, red warning flag.
To avoid troubles, consider using a fall-through transition rule like 
C<[ 'foo', '.', 'foo' ]> to consumer input for input that you don't care
too much about.

Secondly, be careful with code references in transition rules.  They can be
very powerful in their ability to insert data into the input and even
change the entire input (technically, this gives our enhanced FAs all the
power of a Turing machine).  But this leads to the same problem as before.
Input may not be consumed or may grow.  A simple fall-through rule won't help
to avoid this problem, so the programmer must take care to guarantee that input
is actually being consumed.

=head2 Interface

This module is considered alpha, meaning that the interface may change in
future releases without backward compatibility.

=head1 AUTHOR

Mark Rogaski, E<lt>mrogaski@cpan.orgE<gt>

=head1 SEE ALSO

L<Set::FA>.

=cut

#
# clone -- create a deep copy of the object
#
sub clone {
    my($self) = @_;
    my $clone = _deep_copy($self);
    bless $clone, ref $self;
}

#
# _deep_copy -- utility function to create a copy of a nested data
#               structure without identical references
#
sub _deep_copy {
    my($data) = @_;

    use attributes 'reftype';

    return $data unless ref $data;

    if (reftype($data) eq 'ARRAY') {
        return [ map { _deep_copy($_) } @{$data} ];
    } elsif (reftype($data) eq 'HASH') {
        return { map { $_ => _deep_copy($_) } keys %{$data} };
    } elsif (reftype($data) eq 'SCALAR') {
        my $data = _deep_copy($data);
        return \$data;
    } else {
        return $data;
    }
}


