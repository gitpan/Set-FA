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
info: State: bar. Rules:
info: a
info: b
info: c
info: State: baz. This is an accepting state. Rules:
info: .
info: State: foo. This is the start state. Rules:
info: b
info: .
EOS
my(@expect)          = split(/\n/, $expect);
my($stdout, $stderr) = capture{$dfa -> report};
my(@output)          = split(/\n/, $stdout);

ok($output[5] eq $expect[5], 'Reports as expected');
