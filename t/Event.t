#!/usr/bin/perl -w

use strict;

use Test::More;

use lib 'lib';
use Report3::Event;


subtest 'Can require as module' => sub {
    require_ok('Report3::Event');
};

subtest 'object has all need method' => sub {
    can_ok('Report3::Event', qw{_check_previous_report _get_datenow check_etalon log_event} );
};

# параметры для моделирования успешной инициализации объекта
my $param = {
    event	=> '33primer', # shold be cleared up to 33 (digits only)
    dbh	=> 1,
    user	=> {
		    idorgdetails	=> 1,
    },
    cfg	=> {
	    env	=> {
		    USER_PATH	=> './tmp'
	    },
    },
};

subtest 'creates correct object Report3::Event' => sub {
    isa_ok(Report3::Event->new( %$param ), 'Report3::Event');
};


subtest 'event object has an idevent' => sub {
    my $isa = Report3::Event->new( %$param );
    is($isa->{event}->{idevents}, 33, 'to provide idevent to object');
};

done_testing;
