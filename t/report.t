use Capture::Tiny 'capture';

use Test::More tests => 2;

# --------------------------------------

BEGIN{ use_ok('Set::FA::Element'); }

my($dfa) = Set::FA::Element -> new
(
 accepting   => ['baz'],
 start       => 'foo',
 transitions =>
 [
  ['foo', 'b', 'bar'],
  ['foo', '.', 'foo'],
  ['bar', 'a', 'foo'],
  ['bar', 'b', 'bar'],
  ['bar', 'c', 'baz'],
  ['baz', '.', 'baz'],
 ],
 verbose => 1,
);

my($expect) = <<EOS;
debug: Entered report()
debug: State: bar. Rules:
debug: a
debug: b
debug: c
debug: State: baz. This is an accepting state. Rules:
debug: .
debug: State: foo. This is the start state. Rules:
debug: b
debug: .
EOS
my(@expect)          = split(/\n/, $expect);
my($stdout, $stderr) = capture{$dfa -> report};
my(@output)          = split(/\n/, $stdout);

ok($output[5] eq $expect[5], 'Reports as expected');
