#!/usr/bin/perl -w

use strict;

use Test::More;

use lib 'lib';
use Report3::XML;

subtest 'Can require as module' => sub {
    require_ok('Report3::XML');
};

subtest 'object has all need method' => sub {
    can_ok('Report3::XML', qw{prepare_XML} );
};

# параметры для моделирования успешной инициализации объекта
my $param = {
    xsd		=> 1,
    xsdhash	=> 1,
    writer	=> 1,
};

subtest 'creates correct object Report3::XML' => sub {
    isa_ok(Report3::XML->new( %$param ), 'Report3::XML');
};

subtest 'status of new() in Report3::XML is 0 (0 = ok)' => sub {
	my $isa = Report3::XML->new( %$param );
    is( $isa->{status}, 0, 'Report3::XML->{status} is 0 (0 = ok)');
};

done_testing;
