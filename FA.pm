###########################################################################
# $Id: FA.pm,v 1.1 2002/03/18 05:43:00 wendigo Exp $
###########################################################################
#
# Set::FA
#
# RCS Revision: $Revision: 1.1 $
# Date: $Date: 2002/03/18 05:43:00 $
#
# Copyright (C) 2002 Mark Rogaski, mrogaski@cpan.org; all rights reserved.
#
# See the README file included with the
# distribution for license information.
#
# $Log: FA.pm,v $
# Revision 1.1  2002/03/18 05:43:00  wendigo
# Initial revision
#
#
###########################################################################

package Set::FA;

use 5.006;
use strict;
use warnings;
use Set::Object;

our @ISA = qw(Set::Object);

our $VERSION = sprintf "%d.%01d%02d", (split /\D+/, '$Name: beta0_1_1 $')[1..3];

#
# clone -- create a duplicate set
#
sub clone {
    my($self) = @_;

    # create a new set
    my $set = (ref $self)->new();

    # populate the set
    foreach my $member ($self->members) {
        $set->insert($member->clone);
    }

    return $set;
}

#
# id -- find members matching a particular id
#
sub id {
    my($self, $id) = @_;

    # create a new set
    my $set = (ref $self)->new();

    # populate the set
    foreach my $member ($self->members) {
        $set->insert($member) if $member->id eq $id;
    }

    return $set;
}

#
# FA methods
#

#
# accept -- return the subset that accepts the input
#
sub accept {
    my($self, $input) = @_;
    
    # create a new set
    my $set = (ref $self)->new();

    # populate the set
    foreach my $member ($self->members) {
        # it is important that we run this on all members
        $set->insert($member) if $member->accept($input);
    }

    return $set;
}

#
# advance -- advance all member FAs on input
#
sub advance {
    my($self, $input) = @_;

    # iterate through the members
    foreach my $member ($self->members) {
        $member->advance($input);
    }

    return;
}

#
# step -- step all member FAs on input
#
sub step {
    my($self, $input) = @_;

    # iterate through the members
    foreach my $member ($self->members) {
        $member->step($input);
    }

    return;
}

#
# final -- return the subset of members in accepting states
#
sub final {
    my($self) = @_;

    # build a new set
    my $set = (ref $self)->new();

    # populate the set
    foreach my $member ($self->members) {
        $set->insert($member) if $member->final;
    }

    return $set;
}

#
# in_state -- return the subset of members in state specified
#
sub in_state {
    my($self, $state) = @_;

    # build a new set
    my $set = (ref $self)->new();

    # populate the set
    foreach my $member ($self->members) {
        $set->insert($member) if $member->state eq $state;
    }

    return $set;
}

#
# reset -- initialize all members
#
sub reset {
    my($self) = @_;

    # iterate through the members
    foreach my $member ($self->members) {
        $member->reset;
    }
}

1;
__END__

=head1 NAME

Set::FA - Set class for finite automata

=head1 SYNOPSIS

  use Set::FA;
  my $set = Set::FA->new(@evenlist);

=head1 DESCRIPTION

This module provides an interface by which sets of different finite
automata can be constructed.  Normal FA execution, stepwise execution,
and acceptance tests can be performed for each FA on a single input.
The sets can also be manipulated with standard set operations or 
manipulated by state or arbitrary identifier.

=head1 CONSTRUCTOR

=head2 B<new LIST>

Constructs a new Set::FA object.  LIST is an optional list of
Set::FA::Element object references.

See L<Set::FA::Element>.

=head1 SET METHODS

=head2 B<insert [ LIST ]>

Adds elements to the set.  Adding the same object multiple times will result
in a single addition.  The actual number of elements inserted is returned.

=head2 B<includes [ LIST ]>

Return true if all the objects in list are members of the set.
LIST may be empty, in which case true is returned.

=head2 B<members>

Return a list of object references for the members of the set.

=head2 B<id SCALAR>

Returns a subset of the members of the set that have SCALAR as an id.

=head2 B<size>

Return the number of elements in the set.

=head2 B<remove [ LIST ]>

Remove objects from the set.  Removing the same
object more than once, or removing an object absent from
the set is not an error.  Returns the number of
elements that were actually removed.

=head2 B<clear>

Empty the set.

=head2 B<clone>

Return a clone of the set.  All references (except for code references) in the
new set point to newly created objects.

=head2 B<as_string>

Return a textual Smalltalk-ish representation of the set.

Also available as overloaded operator B<"">.

=head2 B<intersection [ LIST ]>

Return a new set containing the intersection of the sets passed as
arguments.

Also available as overloaded operator B<*>.

=head2 B<union [ LIST ]>

Return a new set containing the union of the sets passed as arguments.

Also available as overloaded operator B<+>.

=head2 B<subset SET>

Return true if this set is a subset of SET.

Also available as operator B<<=>.

=head2 B<proper_subset SET>

Return true if this set is a proper subset of SET.

Also available as operator B<<>.

=head2 B<superset SET>

Return true if this set is a superset of SET.

Also available as operator B<E<gt>=>.

=head2 B<proper_superset SET>

Return true if this set is a proper superset of SET.

Also available as operator B<E<gt>>.

=head1 FA METHODS

=head2 B<accept INPUT>

Returns a subset containing the member elements that move to an accepting 
state on the given INPUT.  All members of the superset are advanced using
INPUT, regardless of whether they accept INPUT.

=head2 B<advance INPUT>

Executes all members of the set on INPUT.

=head2 B<final>

Returns a subset containing all memebers of the set that are in an accepting
state.

=head2 B<in_state STATE>

Returns a subset containing all members of the set that are currently in
state STATE.

=head2 B<reset>

Initializes all members to the start state.

=head2 B<step INPUT>

Executes a single step on INPUT, unconsumed output is lost.

=head1 EXPORT

None by default.

=head1 NOTES

At this time, only Set::FA::Element objects are supported as members.  In
the future, I plan to add support for FA::Simple objects, as well as 
nondeterministic FA.

=head1 AUTHOR

Mark Rogaski, E<lt>mrogaski@cpan.orgE<gt>

Many thanks to Philip Gwyn for first suggesting the ideas that led to this
module, even though I don't think I quite answered his original question
... Leolo++.

=head1 SEE ALSO

L<Set::FA::Element>.

For a thorough discussion of finite automata and related topics, I recommend:

  Cohen, Daniel I.A., "Introduction to Computer Theory",
  John Wiley & Sons, Inc.  1991.  ISBN 0-471-51010-6.

=cut

