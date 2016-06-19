#!/usr/bin/perl -w

use strict;

use Test::More;

subtest 'Can require the module' => sub {
	require_ok('AlekseiAnanevFindIndex');
};

subtest 'object has constructor method find' => sub {
	can_ok('AlekseiAnanevFindIndex', qw{new find} );
};

subtest 'creates correct object' => sub {
	isa_ok(AlekseiAnanevFindIndex->new(), 'AlekseiAnanevFindIndex');
};

subtest 'event object has an idevent' => sub {
	my $isa = AlekseiAnanevFindIndex->new();
	my @arr = ( 1, 2, 5, 8 );

	is( ($isa->find( 0 , \@arr))[0], 0, 'over by left, index');
	is( ($isa->find( 0 , \@arr))[1], 0, 'over by left, step');
	is( ($isa->find( 9 , \@arr))[0], 3, 'over by right, index');
	is( ($isa->find( 9 , \@arr))[1], 0, 'over by right, step');

	is( ($isa->find( 5 , \@arr))[0], 2, 'equal');
	is( ($isa->find( 6 , \@arr))[0], 2, 'near to left');
	is( ($isa->find( 7 , \@arr))[0], 3, 'near to right');

	is( ($isa->find( 1 , \@arr))[0], 0, 'first element');
	is( ($isa->find( 8 , \@arr))[0], 3, 'last element');
};

done_testing;
