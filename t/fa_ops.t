#!perl
###########################################################################
# $Id: fa_ops.t,v 1.1 2002/03/18 05:43:00 wendigo Exp $
###########################################################################
#
# Author: Mark Rogaski <mrogaski@cpan.org>
# RCS Revision: $Revision: 1.1 $
# Date: $Date: 2002/03/18 05:43:00 $
#
###########################################################################
#
# See README for license information.
# 
###########################################################################
use Test;

BEGIN { plan tests => 21 }

use Set::FA;
use Set::FA::Element;
ok(1);

my(@a) = map {
    Set::FA::Element->new(
        id => "pingpong_".$_,
        states => [ qw( ping pong ) ],
        transitions => [
            [ 'ping', 'a', 'pong' ],
            [ 'ping', '.', 'ping' ],
            [ 'pong', 'b', 'ping' ],
            [ 'pong', '.', 'pong' ]
        ],
        accept => [ 'ping' ]
    ) } (0..2);

my(@b) = map {
    Set::FA::Element->new(
        id => "pongping_".$_,
        states => [ qw( ping pong ) ],
        transitions => [
            [ 'ping', 'a', 'pong' ],
            [ 'ping', '.', 'ping' ],
            [ 'pong', 'b', 'ping' ],
            [ 'pong', '.', 'pong' ]
        ],
        accept => [ 'pong' ]
    ) } (0..4);

my(@c) = map {
    Set::FA::Element->new(
        id => "dog_".$_,
        states => [ qw( sad happy ) ],
        transitions => [
            [ 'sad', 'dog', 'happy' ],
            [ 'sad', '.', 'sad' ],
            [ 'happy', '.', 'happy' ]
        ],
        accept => [ 'happy' ]
    ) } (0..6);

my $set = Set::FA->new(@a, @b, @c);

my $sub_a = $set->accept('abbba');
my $sub_b = $set->final;
ok($sub_a->size, scalar @b);
ok($sub_a->includes(@b));
ok($sub_b->size, scalar @b);
ok($sub_b->includes(@b));

$set->reset;
$sub_b = $set->final;
ok($sub_b->size, scalar @a);
ok($sub_b->includes(@a));

$sub_a = $set->accept('aaabbaaabdogbbbbbababa');
$sub_b = $set->final;
ok($sub_a->size, @b + @c);
ok($sub_a->includes(@b, @c));
ok($sub_b->size, @b + @c);
ok($sub_b->includes(@b, @c));

ok($set->in_state('ping')->size, 0);
ok($set->in_state('pong')->size, @a + @b);
ok($set->in_state('sad')->size, 0);
ok($set->in_state('happy')->size, @c);

$sub_a->reset;
$set->step('b');
ok($set->in_state('ping')->size, @a + @b);
ok($set->in_state('pong')->size, 0);
ok($set->in_state('sad')->size, @c);
ok($set->in_state('happy')->size, 0);
ok($set->final->size, @a);
ok($set->final->includes(@a));


