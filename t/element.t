#!perl
###########################################################################
# $Id: element.t,v 1.1 2002/03/18 05:43:00 wendigo Exp $
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

BEGIN { plan tests => 42 }

use Set::FA::Element;
use vars qw( $inct $outct );
ok(1);

my $fa = Set::FA::Element->new(
    states => [ qw( foo bar baz ) ],
    transitions => [
        [ "foo", 'b', "bar" ],
        [ "foo", '.', "foo" ],
        [ "bar", 'a', "foo" ],
        [ "bar", 'b', "bar" ],
        [ "bar", 'c', "baz" ],
        [ "baz", '.', "baz" ]
    ],
    accept => [ 'baz' ]
);

ok(UNIVERSAL::isa($fa, 'Set::FA::Element'));
ok($fa->state('bar'));
ok(! $fa->state('new_jersey'));
ok($fa->final('baz'));
ok(! $fa->final('bar'));

ok($fa->step('a'), '');
ok($fa->state, 'foo');
ok(! $fa->final);

ok($fa->step('aa'), 'a');
ok($fa->state, 'foo');
ok(! $fa->final);

ok($fa->step('bar'), 'ar');
ok($fa->state, 'bar');
ok(! $fa->final);

ok($fa->step('c'), '');
ok($fa->state, 'baz');
ok($fa->final);

ok($fa->step('cca'), 'ca');
ok($fa->state, 'baz');
ok($fa->final);

ok($fa->step('boo'), 'oo');
ok($fa->state, 'baz');
ok($fa->final);

ok($fa->reset, 'foo');
ok($fa->state, 'foo');

ok($fa->advance('a'), 'foo');
ok($fa->advance('ac'), 'foo');
ok($fa->advance('aaaccb'), 'bar');
ok($fa->advance('acacbcaaba'), 'baz');

$fa = Set::FA::Element->new(
    states => [ qw( foo bar baz ) ],
    transitions => [
        [ "foo", 'b', "bar" ],
        [ "foo", '.', "foo" ],
        [ "bar", 'a', "foo" ],
        [ "bar", 'b', "bar" ],
        [ "bar", 'c', "baz" ],
        [ "baz", '.', "baz" ]
    ],
    actions => {
        bar => {
            entry => sub { $inct++; },
            exit  => sub { $outct++; }
        }
    },
    accept => [ 'baz' ]
);

ok(! $fa->accept('abababa'));
ok($inct, 3);
ok($outct, 3);

$fa->reset;
ok($fa->accept('bbbc'));
ok($inct, 4);
ok($outct, 4);

$fa->reset;
ok(! $fa->accept('cccbbbaaa'));
ok($inct, 5);
ok($outct, 5);

$fa->reset;
ok($fa->accept('ababababc'));
ok($inct, 9);
ok($outct, 9);


