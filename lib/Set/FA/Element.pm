package Set::FA::Element;

use strict;
use warnings;

use Hash::FieldHash ':all';

fieldhash my %accepting   => 'accepting';
fieldhash my %actions     => 'actions';
fieldhash my %current     => 'current';
fieldhash my %data        => 'data';
fieldhash my %die_on_loop => 'die_on_loop';
fieldhash my %id          => 'id';
fieldhash my %logger      => 'logger';
fieldhash my %match       => 'match';
fieldhash my %start       => 'start';
fieldhash my %stt         => 'stt';
fieldhash my %transitions => 'transitions';
fieldhash my %verbose     => 'verbose';

our $VERSION = '1.03';

# -----------------------------------------------

sub accept
{
	my($self, $input) = @_;

	$self -> log(debug => 'Entered accept()');

	return $self -> final($self -> advance($input) );

} # End of accept.

# -----------------------------------------------

sub advance
{
	my($self, $input) = @_;

	$self -> log(debug => 'Entered advance()');

	my($output);

	while ($input)
	{
		$output = $self -> step($input);

		if (length($output) >= length($input) )
		{
			$self -> log( ($self -> die_on_loop ? 'error' : 'warning') => "State: '" . $self -> current . "' is not consuming input");
		}

		$input = $output;
	}

	return $self -> current;

} # End of advance.

# -----------------------------------------------

sub build_stt
{
	my($self)   = @_;
	my(%action) = %{$self -> actions};

	# Reformat the actions.

	my($entry_exit);
	my($state);
	my($trigger);

	for $state (keys %action)
	{
		for $trigger (keys %{$action{$state} })
		{
			if ($trigger !~ /^(entry|exit)$/)
			{
				$self -> log(error => "Action table contains the unknown trigger '$trigger'. Use entry/exit");
			}
		}
	}

	# Reformat the acceptings.

	my(@accepting) = @{$self -> accepting};
	my($row)       = 0;

	my(%accept);
	my($last);
	my($next);
	my($rule_sub, $rule);
	my(%stt);

	@accept{@accepting} = (1) x @accepting;

	for my $item (@{$self -> transitions})
	{
		$row++;

		if (ref($item ne 'ARRAY') || ($#$item < 2) )
		{
			$self -> log(error => "Transition table row $row has too few columns");
		}

		($state, $rule, $next) = @$item;

		# Allow first column of transition table to be empty (meaning ditto),
		# as long as there is a state name somewhere above the missing element.

		if (! defined $state)
		{
			$state = $last;
		}

		if (! defined($state && $rule && $next) )
		{
			$self -> log(error => "Transition table row $row lacks state name/rule/next state name");
		}

		if (ref($rule) eq 'CODE')
		{
			$rule_sub = $rule;
		}
		else
		{
			# Warning: $regexp must be declared in this scope.

			my($regexp) = qr/($rule)/;
			$rule_sub   = sub
			{
				my($class, $input) = @_;

				return $input =~ /^$regexp(.*)/ ? ($1, $2) : (undef, undef);
			};
		}

		# The 3rd item in each arrayref is only used for debugging.

		if ($stt{$state})
		{
			push @{$stt{$state}{rule} }, [$rule_sub, $next, $rule];
		}
		else
		{
			$stt{$state} =
			{
				accept => $accept{$state} || 0,
				entry  => $action{$state} && $action{$state}{entry} ? $action{$state}{entry} : '',
				exit   => $action{$state} && $action{$state}{exit}  ? $action{$state}{exit}  : '',
				rule   => [ [$rule_sub, $next, $rule] ],
				start  => 0,
			};
		}

		$last = $state;
	}

	$state = $self -> start;

	if ($stt{$state})
	{
		$stt{$state}{start} = 1;
	}
	else
	{
		$self -> log(error => "Start state '$state' is not defined in the transition table");
	}

	for $state (@accepting)
	{
		if (! $stt{$state})
		{
			$self -> log(error => "Accepting state '$state' is not defined in the transition table");
		}
	}

	$self -> stt(\%stt);

} # End of build_stt.

# -----------------------------------------------

sub clone
{
	my($self) = @_;

	$self -> log(debug => 'Entered clone()');

	my($clone) = _clone($self);

	return bless $clone, ref $self;

} # End of clone.

# -----------------------------------------------

sub _clone
{
	my($data) = @_;

	use attributes 'reftype';

	return $data if (! ref $data);

	if (reftype($data) eq 'ARRAY')
	{
		return [map{_clone($_)} @$data];
	}
	elsif (reftype($data) eq 'HASH')
	{
		return {map{$_ => _clone($_)} keys %$data};
	}
	elsif (reftype($data) eq 'SCALAR')
	{
		my($thing) = _clone($data);

		return \$thing;
	}
	else
	{
		return $data;
	}

} # End of _clone.

# -----------------------------------------------

sub final
{
	my($self, $state) = @_;

	$self -> log(debug => 'Entered final()');

	my($stt) = $self -> stt;

	return defined($state) ? $$stt{$state}{accept} : $$stt{$self -> current}{accept};

} # End of final.

# -----------------------------------------------

sub _init
{
	my($self, $arg)    = @_;
	$$arg{accepting}   ||= []; # Caller can set.
	$$arg{actions}     ||= {}; # Caller can set.
	$$arg{current}     = '';
	$$arg{data}        ||= ''; # Caller can set.
	$$arg{die_on_loop} ||= 0;  # Caller can set.
	$$arg{id}          ||= 0;  # Caller can set.
	$$arg{logger}      ||= ''; # Caller can set.
	$$arg{match}       = '';
	$$arg{start}       ||= ''; # Caller must set.
	$$arg{stt}         = {};
	$$arg{transitions} ||= []; # Caller must set.
	$$arg{verbose}     ||= 0;  # Caller can set.
	$self              = from_hash($self, $arg);

	$self -> validate_params;
	$self -> build_stt;
	$self -> current($self -> start);

	return $self;

} # End of _init.

# -----------------------------------------------

sub log
{
	my($self, $level, $message) = @_;
	$level   ||= 'debug';
	$message ||= '';

	$self -> logger ? $self -> logger -> log($level => $message) : $level eq 'error' ? die $message : $self -> verbose ? print "$level: $message\n" : '';

} # End of log.

# -----------------------------------------------

sub new
{
	my($class, %arg) = @_;
	my($self)        = bless {}, $class;

	return $self -> _init(\%arg);

}	# End of new.

# -----------------------------------------------

sub report
{
	my($self) = @_;

	$self -> log(debug => 'Entered report()');

	my($stt) = $self -> stt;

	my($rule);
	my($s);

	for my $state (sort keys %$stt)
	{
		$s = "State: $state";

		if ($$stt{$state}{start})
		{
			$s .= '. This is the start state';
		}

		if ($$stt{$state}{accept})
		{
			$s .= '. This is an accepting state';
		}

		if ($$stt{$state}{entry})
		{
			$s .= ". Entry fn: $$stt{$state}{entry}";
		}

		if ($$stt{$state}{exit})
		{
			$s .= ". Exit fn: $$stt{$state}{exit}";
		}

		$self -> log(info => $s);
		$self -> log(info => 'Rule => Next state');

		for $rule (@{$$stt{$state}{rule} })
		{
			$self -> log(info => "/$$rule[2]/ => $$rule[1]");
		}
	}

} # End of report.

# -----------------------------------------------

sub reset
{
	my($self) = @_;

	$self -> log(debug => 'Entered reset()');

	return $self -> current($self -> start) -> current;

} # End of reset.

# -----------------------------------------------

sub state
{
	my($self, $state) = @_;

	$self -> log(debug => 'Entered state()');

	return defined($state) ? (${$self -> stt}{$state} ? 1 : 0) : $self -> current;

} # End of state.

# -----------------------------------------------

sub step
{
	my($self, $input) = @_;

	$self -> log(debug => 'Entered step()');

	my($current) = $self -> current;
	my($stt)     = $self -> stt;

	my($match);
	my($next);
	my($output);
	my($rule_sub, $rule);

	for my $item (@{$$stt{$current}{rule} })
	{
		($rule_sub, $next, $rule) = @$item;
		($match, $output)         = $rule_sub -> ($self, $input);
 
		if (defined $match)
		{
			$self -> match($match);
			$self -> step_state($next);

			return $output;
		}
	}

	return $input;

} # End of step.

# -----------------------------------------------

sub step_state
{
	my($self, $next) = @_;

	$self -> log(debug => 'Entered step_state()');

	my($current) = $self -> current;

	return 0 if ($next eq $current);

	my($stt) = $self -> stt;

	if ($$stt{$current}{exit})
	{
		$$stt{$current}{exit} -> ($self);
	}

	$self -> current($next);

	if ($$stt{$next}{entry})
	{
		$$stt{$next}{entry} -> ($self);
	}

	$self -> log(warning => "Successfully advanced from state '$current' to '$next'");

	return 1;

} # End of step_state;

# -----------------------------------------------

sub validate_params
{
	my($self) = @_;

	if ( (ref $self -> accepting ne 'ARRAY') || ($#{$self -> accepting} < 0) )
	{
		$self -> log(error => 'No accepting states specified. Use accepting');
	}

	if (! $self -> start)
	{
		$self -> log(error => 'No start state specified. Use start');
	}

	if ( (ref $self -> transitions ne 'ARRAY') || ($#{$self -> transitions} < 0) )
	{
		$self -> log(error => 'No state transition table specified. Use transitions');
	}

} # End of validate_params;

# -----------------------------------------------

1;

=pod

=head1 NAME

L<Set::FA::Element> - Discrete Finite Automaton

=head1 Synopsis

	#!/usr/bin/perl
	
	use strict;
	use warnings;
	
	use Set::FA::Element;
	
	# --------------------------
	
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
	);
	
	my($boolean)  = $dfa -> accept($input);
	my($current)  = $dfa -> advance($input);
	my($state)    = $dfa -> current;
	my($boolean)  = $dfa -> final;
	my($acceptor) = $dfa -> final($state);
	my($string)   = $dfa -> match;
	my($current)  = $dfa -> reset;
	my($current)  = $dfa -> state;
	my($boolean)  = $dfa -> state($state);
	my($string)   = $dfa -> step($input);
	my($boolean)  = $dfa -> step_state($next);

=head1 Description

L<Set::FA::Element> provides a mechanism to define and run a DFA.

=head1 Installation

Install L<Set::FA> as you would for any C<Perl> module:

Run:

	cpanm Set::FA

or run:

	sudo cpan Set::FA

or unpack the distro, and then either:

	perl Build.PL
	./Build
	./Build test
	sudo ./Build install

or:

	perl Makefile.PL
	make (or dmake or nmake)
	make test
	make install

=head1 Constructor and Initialization

=head2 Parentage

You can easily subclass L<Set::FA::Element> by having your subclass use exactly the same logic as in the code,
- see new(), and _init() - after declaring your getters and setters using the Hash::FieldHash syntax.

=head2 Using new()

C<new()> is called as C<< my($dfa) = Set::FA::Element -> new(k1 => v1, k2 => v2, ...) >>.

It returns a new object of type C<Set::FA::Element>.

Key-value pairs accepted in the parameter list are as follows. Also, each is also a method,
so you can retrieve the value and update it at any time.

Naturally, after the internal state transition table has been constructed (during the call to new() ),
updating some of these fields will be ignored. Methods which I<are> effective later are documented.

=over 4

=item o accepting => []

Provides an arrayref of accepting state names.

This key is optional.

The default is [].

=item o actions => {}

Provides a hashref of entry/exit functions keyed by state name.

This means you can have only 1 entry function and 1 exit function per state.

For a module which gives you the power to have a different entry and exit function
for each different regexp which matches the input, see the (as yet unwritten) Set::FA::Manifold.

Format:

=over 4

=item o entry => function_name

The 'entry' key points to the name of a function called upon entry to a state.

=item o exit => function_name

The 'exit' key points to the name of a function called upon exit from a state.

=back

Each of these functions is called (in method step_state() ) with the DFA object as the only parameter.

This key is optional.

The default is {}.

=item o data => $string

A place to store anything you want, per DFA.

Retrieve and update the value with the data() method.

This key is optional.

The default is ''.

=item o die_on_loop => $boolean

Provides a way for the code to keep running, or die, when the advance() method determines that
input is not being consumed.

Setting die_on_loop to 0 means keep running.

Setting die_on_loop to 1 means the code dies, after outputting an error message.

Retrieve and update the value with the die_on_loop() method.

This key is optional.

The default is 0.

=item o id => $string

Provides a place to store some sort of identifier per DFA object.

Retrieve and update the value with the id() method.

This key is optional.

The default is ''.

=item o logger => $logger_object

Provides a logger object whose log($level => $message) method is called at certain times.

See L</Why such a different approach to logging?> in the L</FAQ> for details.

Retrieve and update the value with the logger() method.

This key is optional.

The default is ''.

See also the verbose option, which can interact with the logger option.

=item o start => $name_of_start_state

Provides the name of the start state.

Retrieve and update the value with the start() method.

This key is mandatory.

There is no default.

=item o transitions => []

Provides a complex arrayref of state names and regexps which control the transitions between states.

Each element of this arrayref is itself an arrayref of 3 elements:

=over 4

=item o [0] ($state)

The name of the state, which has to match the 'current' state, before other elements of this
arrayref are utilized.

=item o [1] ($regexp)

The regexp, as a string, against which the input is tested, to determine whether or not to
move to the next state.

This string may be a coderef. As such, it should contain 2 pairs of parentheses. The first
must capture the matched portion of the input, and the second must capture the unmatched portion
of the  input.

If it is not a coderef, it is wrapped in qr/($regexp)/ and turned into a coderef which returns
the 2 portions of the input as described in the previous sentence.

The code supplies the extra parentheses in the qr// above so that the matched portion of the input
can be retrieved with the match() method.

If the regexp does not match, (undef, undef) must be returned by the coderef.

=item o [2] ($next)

The name of the state to which the DFA will move when the regexp matches the input.

The string which matched, if any, can be retrieved with the match() method.

The name of the new state can be retrieved with the current() method.

=back

This key is mandatory.

There is no default.

=item o verbose => $boolean

Provides a way to control the amount of output when a logger is not specified.

Setting verbose to 0 means print nothing.

Setting verbose to 1 means print the log level and the message to STDOUT, when a logger is not specified.

This key is optional.

Retrieve and update the value with the verbose() method.

The default is 0.

See also the logger option, which can interact with the verbose option.

=back

=head1 Methods

Note: Methods generated by Hash::FieldHash are designed to operate like this:

=over 4

=item o When called without a parameter...

They return the value they are managing. Hence:

	my($current_state) = $dfa -> current.

=item o When called with a parameter...

They return the object, to allow method chaining. Hence:

	$dfa -> current($new_state);
	my($current_state) = $dfa -> current;

Don't do this:

	my($current_state_no_no) = $dfa -> current($new_state);

You could do this:

	my($current_state) = $dfa -> current($new_state) -> current;

=back

All such methods below warn of this.

=head2 accept($input)

Calls L</advance($input)>.

Returns 1 if the 'current' state - after processing the input - is an accepting state.

Returns 0 otherwise.

=head2 advance($input)

Calls L</step($input)> repeatedly on the unconsumed portion of the input.

Returns the 'current' state at the end of that process.

Since L</step($input)> calls L</match($consumed_input)> upon every match, and L</step_state($next)> too, you
necessarily lose access to the individual portions of the input matched by successive
runs of the coderef per transition table entry.

At the end of this process, then, L</match($consumed_input)> can only return the last portion matched.

See L</step($input)> for advancing the DFA by a single transition.

Logging note:

=over 4

=item o When die_on_loop is 0

Then, advance() calls log(warning => $message) on the logger, if any, when input is not consumed.

If there is no logger, calls print "$message\n". But, when verbose is 0, does nothing.

=item o When die_on_loop is 1

Then, advance() calls log(error => $message) on the logger, if any, when input is not consumed.

If there is no logger, calls print "$message\n". But, when verbose is 0, dies.

=back

=head2 build_stt()

Use these parameters to new() to construct a state transition table:

=over 4

=item o accepting

=item o actions

=item o start

=item o transitions

=back

Note: The private method _init() calls validate_params() I<before> calling build_stt(), so if
you call accepting($new_accepting), actions($new_actions), start($new_start) and transtions($new_transitions),
for some reason, and then call build_stt(), you will miss out on the benefit of calling validate_params().
So don't do that!

=head2 clone()

Returns a deep copy of the L<Set::FA::Element> object.

=head2 current([$state])

Here, the [] indicate an optional parameter.

=over 4

=item o When $state is not provided

Returns the 'current' state of the DFA.

=item o When $state is provided

Sets the 'current' state of the DFA.

Returns the object, for method chaining.

=back

=head2 data([$string])

Here, the [] indicate an optional parameter.

=over 4

=item o When $string is not provided

Returns the data associated with the object.

=item o When $data is provided

Sets the data associated with the object.

Returns the object, for method chaining.

=back

=head2 final([$state])

Here, the [] indicate an optional parameter.

=over 4

=item o When $state is not provided

Returns 1 if the 'current' state is an accepting state.

Returns 0 otherwise.

=item o When $state is provided

Returns 1 if $state is an accepting state.

Returns 0 otherwise.

=back

=head2 id([$id])

Here, the [] indicate an optional parameter.

=over 4

=item o When $id is not provided

Returns the id of the object.

=item o When $id is provided

Sets the id of the object.

Returns the object, for method chaining.

=back

=head2 log($level, $message)

If you call it as $dfa -> log(), $level defaults to 'debug' and $message defaults to ''.

log() then executes this, admittedly complex, line:

	$self -> logger                              # If there is a logger...
	? $self -> logger -> log($level => $message) # Call it.
	: $level eq 'error'                          # Otherwise (no logger) and it's an error...
	? die $message                               # Die.
	: $self -> verbose                           # Otherwise (no error) and we're verbose...
	? print "$level: $message\n"                 # Print.
	: '';                                        # Otherwise (silent) do nothing.

=head2 logger([$logger_object])

Here, the [] indicate an optional parameter.

=over 4

=item o When $logger_object is not provided

Returns the logger object.

=item o When $logger_object is provided

Sets the logger object.

This allows you to change the log levels accepted and suppressed by the logger object,
during the run of the DFA.

You are strongly advised to read the discussion of logging in the L</FAQ>, as well as the notes
on the logging and verbose options to new().

Returns the object, for method chaining.

=back

=head2 match([$consumed_input])

Here, the [] indicate an optional parameter.

=over 4

=item o When $consumed_input is not provided

Returns the portion of the input matched by the most recent step of the DFA.

=item o When $consumed_input is provided

Sets the internal string which will be returned by calling match().

Returns the object, for method chaining.

=back

=head2 reset()

Resets the DFA object to the start state.

Returns the 'current' state, which will be the start state.

Does not reset the id or anything else associated with the object.

=head2 start([$start])

Here, the [] indicate an optional parameter.

=over 4

=item o When $start is not provided

Returns the start state of the object.

=item o When $start is provided

Sets the start state of the object.

Returns the object, for method chaining.

=back

=head2 state([$state])

Here, the [] indicate an optional parameter.

=over 4

=item o When $state is not provided

Returns the 'current' state.

=item o When $state is provided

Returns 1 if $state was defined in the transitions arrayref supplied to new().

Returns 0 otherwise.

=back

=head2 step($input)

Advances the DFA by a single transition, if possible.

The code checks each entry in the transitions arrayref supplied to new(), in order,
looking for entries whose 1st element ($state) matches the 'current' state.

Upon the first match found (if any), the code runs the coderef in the 2nd element ($rule_sub) of that entry.

If there is a match:

=over 4

=item o Calls L</match($consumed_input)> so you can retrieve that value with the match() method

=item o Calls L</step_state($next)>, passing in the 3rd element ($next) in that entry
as the only parameter

=back

Returns the unconsumed portion of the input.

=head2 step_state($next)

Performs these steps:

=over 4

=item o Compares the 'current' state to $next

If they match, returns 0 immediately.

=item o Calls the exit function, if any, of the 'current' state

=item o Set the 'current' state to $next

=item o Calls the entry function, if any, of the new 'current' state

=item o Returns 1.

=back

=head2 validate()

Perform validation checks on these parameters to new():

=over 4

=item o accepting

=item o start

=item o transitions

=back

=head1 FAQ

=head2 What's changed in V 1.00 of L<Set::FA::Element>?

=over 4

=item o Use Hash::FieldHash for getters and setters

Originally, L<Set::FA::Element> used direct hash access to implement the logic.
I did not want to do that. At the same time, I did not want users to incur the overhead
of L<Moose>.

So, I've adopted my standard policy of using L<Hash::FieldHash> in stand-alone modules and L<Moose> in apps.

=item o Rename the new() parameter from accept to accepting

While direct hash access allowed the author of L<Set::FA::Element> to have a hash key and a method with the
same name, accept, I can't do that now.

So, the parameter to new() (in L<Set::FA::Element>) is called accepting, and the method is still called accept().

=item o Add a parameter to new(), die_on_loop

This makes it easy to stop a run-away program during development.

=item o Add a parameter to new(), logger

See below for details.

=item o Add a parameter to new(), start

This must be used to name the start state.

=item o Chop the states parameter to new()

The state names are taken from the transitions parameter to new().

=item o Add a parameter to new(), verbose

This makes it easy to change the quantity of progress reports.

=item o Add a method, build_stt() to convert new()'s parameters into a state transition table

=item o Add a method, current() to set/get the current state

=item o Add a method, data() to set/get the arbitrary data per object

=item o Add a method, die_on_loop() to set/get the like-named option

=item o Add a method, id() to set/get the id per object

=item o Add a method, log() to call the logger object

=item o Add a method, logger() to set/get the logger object

=item o Add a method, match(), to retrieve exactly what matched at each transition

=item o Add a method, report(), to print the state transition table

=item o Add a method, start() to set/get the start state per object

=item o Add a method, validate() to validate new()'s parameters

=item o Add a method, verbose() to set/get the like-named option

=back

=head2 Why such a different approach to logging?

Firstly, L<Set::FA::Element> used L<Log::Agent>. I always use L<Log::Handler> these days.

By default (i.e. without a logger object), L<Set::FA::Element> prints warning and debug messages to STDOUT,
and dies upon errors.

However, by supplying a log object, you can capture these events.

Not only that, you can change the behaviour of your log object at any time, by calling
L</logger($logger_object)>.

Specifically, $logger_object -> log(debug => 'Entered x()') is called at the start of each public method.

Setting your log level to 'debug' will cause these messages to appear.

Setting your log level to 'warning' or 'error' will suppress them.

Also, L</step_state($next)> calls log(warning => "Successfully advanced from '$old_state' to '$new_state'")
just before it returns.

Setting your log level to error will suppress this message.

Hence, by setting the log level to 'warning', you can log just 1 line per state transition, and no other
messages, to minimize output.

Lastly, although this logging mechanism may seem complex, it has distinct advantages:

=over 4

=item o A design fault in L<Log::Agent>

This method uses a global variable to control the level of logging. This means the code using
L<Set::FA::Element> can (also) use L<Log::Agent> and call logconfig(...),
which in turn affects the behaviour of the logging calls inside those other modules.
I assume this design is deliberate, but I certainly don't like it, because (I suspect) it means any running Perl
program which changes the configuration affects all other running programs using L<Log::Agent>.

=item o Log levels

Debug and warning messages can be suppressed by configuring your logger object, either before calling new()
or at any later time.

=item o Even better, you can intercept calls to your logger object's log() method

For instance, you could pass in $self as new(logger => $self) from the object using L<Set::FA::Element>,
so that when L<Set::FA::Element> calls $logger -> log(...), it calls your object's log() method.

In other words, your object's log method is called, and you can then delegate the call to the real logger.

That allows you complete control over the logging activity.

=item o This module documents its debug and warning messages.

Error messages are self-documenting, in that when you trigger them, you get to read them...

=back

=head1 Machine-Readable Change Log

The file CHANGES was converted into Changelog.ini by L<Module::Metadata::Changes>.

=head1 Version Numbers

Version numbers < 1.00 represent development versions. From 1.00 up, they are production versions.

=head1 Credit

See L<Set::FA/Credit>.

=head1 See Also

See L<Set::FA/See Also>.

=head1 Support

Email the author, or log a bug on RT:

L<https://rt.cpan.org/Public/Dist/Display.html?Name=Set::FA>.

=head1 Author

L<Set::FA::Element> was written by Mark Rogaski and Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2011.

Home page: L<http://savage.net.au/index.html>.

=head1 Copyright

Australian copyright (c) 2011, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
