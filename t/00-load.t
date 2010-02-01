#!perl -T

use Test::More tests => 3;

BEGIN {
	use_ok( 'Bot::NotSoBasicBot' );
	use_ok( 'Bot::Listener' );
	use_ok( 'Bot::Roberts' );
}

diag( "Testing Bot::NotSoBasicBot $Bot::NotSoBasicBot::VERSION, Perl $], $^X" );
