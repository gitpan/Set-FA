use Module::Build;

Module::Build -> new
(
 module_name    => 'Set::FA',
 license        => 'artistic',
 dist_abstract  => 'A Set of Discrete Finite Automata',
 dist_author    => 'Ron Savage <ron@savage.net.au>',
 build_requires =>
 {
 	 Test::More => 0.94,
 	 Test::Pod  => 1.44,
 },
 configure_requires =>
 {
 	 Module::Build => 0.3800,
 },
 requires =>
 {
	 attributes      => 0.12,
	 Capture::Tiny   => 0.10, # For testing.
	 Hash::FieldHash => 0.10,
	 parent          => 0.224,
	 Set::Object     => 1.28,
 },
) -> create_build_script();
