#!perl
###########################################################################
# $Id: set_ops.t,v 1.1 2002/03/18 05:43:00 wendigo Exp $
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

BEGIN { plan tests => 44 }

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

my $set;
ok($set = Set::FA->new(@a, @b));
ok(! $set->includes(@a, @b, @c));

ok($set->insert(@c), 7);
ok($set->includes(@a, @b, @c));

ok(! grep { ! $set->includes($_) } $set->members);
ok($set->size, 3+5+7);
ok($set->id('dog_3')->size, 1);

ok($set->remove(@b), 5);
ok($set->size, 3+7);

$set->clear;
ok($set->size, 0);
$set->insert(@a, @b, @c);

my $subset = Set::FA->new(@a, @c);
my $bizzaro_set;
ok($bizzaro_set = $set->clone);

ok($set->union($bizzaro_set)->size, 2*(3+5+7));
ok(($set + $bizzaro_set)->size, 2*(3+5+7));
ok($set->union($subset)->size, 3+5+7);
ok(($set + $subset)->size, 3+5+7);

ok($set->intersection($bizzaro_set)->size, 0);
ok(($set * $bizzaro_set)->size, 0);
ok($set->intersection($subset)->size, 3+7);
ok(($set * $subset)->size, 3+7);

ok(! $set->subset($subset));
ok($subset->subset($set));
ok($set->subset($set));
ok(! ($set <= $subset));
ok($subset <= $set);
ok($set <= $set);

ok(! $set->proper_subset($subset));
ok($subset->proper_subset($set));
ok(! $set->proper_subset($set));
ok(! ($set < $subset));
ok($subset < $set);
ok(! ($set < $set));

ok($set->superset($subset));
ok(! $subset->superset($set));
ok($set->superset($set));
ok($set >= $subset);
ok(! ($subset >= $set));
ok($set >= $set);

ok($set->proper_superset($subset));
ok(! $subset->proper_superset($set));
ok(! $set->proper_superset($set));
ok($set > $subset);
ok(! ($subset > $set));
ok(! ($set > $set));


