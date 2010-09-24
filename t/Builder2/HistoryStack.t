#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';

use Test::Builder2::Result;

require_ok 'Test::Builder2::HistoryStack';
can_ok( 'Test::Builder2::HistoryStack', 
        qw{ singleton
            create
            
            results
            has_results
            add_test_history
            add_result
            add_results
            result_count

          },
);
      
# helpers
sub new_history { Test::Builder2::HistoryStack->create }
sub Pass { Test::Builder2::Result->new_result( pass => 1, @_ ) }
sub Fail { Test::Builder2::Result->new_result( pass => 0, @_ ) }


{ 
    ok my $history = new_history, q{new history} ;
    ok!$history->has_results, q{we no not yet have results};
    is_deeply $history->results, [], q{blank results set};
    ok $history->add_result( Pass() ), q{add pass};
    ok $history->add_test_history( Fail() ), q{add fail};
    ok $history->add_results( Pass(), Fail() ), q{can add multiples};
    ok $history->has_results, q{we have results};
    
    is $history->result_count, 4, q{count looks good};
    is $history->test_count, 4, q{test_count};

    is $history->pass_count, 2, q{pass_count};
    is $history->fail_count, 2, q{fail_count};
    is $history->todo_count, 0, q{todo_count};
    is $history->skip_count, 0, q{skip_count};

}

# merge history stacks
{
   my $H1 = new_history;
   $H1->add_results(Pass(),Pass(),Pass());
   is $H1->result_count, 3, q{H1 count};
   my $H2 = new_history;
   $H2->add_results(Fail(),Fail(),Fail());
   is $H2->result_count, 3, q{H2 count};

   ok $H1->consume($H2);
   is $H1->result_count, 6, q{H1 consumed H2};
   is $H1->fail_count, 3 , q{H1 picked up the tests from H2 correctly};

   ok $H1->consume( map{ my $h = new_history; $h->add_results(Pass(),Fail());$h } 1..10 ),
      q{consume can also take lists of objects}
   ;

   is $H1->result_count, 26, q{H1 consumed all the items in that list};
   
}

# multiple results with same test number
{
   my $h = new_history;
   ok $h->add_results(Pass(test_number=>1), Pass(test_number=>1));
   is $h->result_count,2;
}

{
   my $h = new_history;
   ok $h->add_event('BEGIN 1');
   ok $h->add_result(Pass());
   ok $h->add_event(Fail());
   is $h->results_count, 1;
   is $h->events_count, 3;
}












__END__
my $CLASS = "Test::Builder2::History";
require_ok 'Test::Builder2::History';


my $Pass = Test::Builder2::Result->new_result(
    pass => 1,
);

my $Fail = Test::Builder2::Result->new_result(
    pass => 0,
);

my $create_ok = sub {
    my $history = $CLASS->create;
    isa_ok $history, $CLASS;
    return $history;
};


# Testing initialization
{
    my $history = $create_ok->();

    is $history->counter->get,          0;
    is_deeply $history->results,        [];
    ok $history->should_keep_history;
}


# Test the singleton nature
{
    my $history1 = $CLASS->singleton;
    isa_ok $history1, $CLASS;
    my $history2 = $CLASS->singleton;
    isa_ok $history2, $CLASS;

    is $history1, $history2,            "new() is a singleton";

    my $new_history = $create_ok->();
    $CLASS->singleton($new_history);
    is   $CLASS->singleton,  $new_history,  "singleton() set";
}


# add_test_history
{
    my $history = $create_ok->();

    $history->add_test_history( $Pass );
    is_deeply $history->results, [$Pass];
    is_deeply [$history->summary], [1];

    is $history->counter->get, 1;
    ok $history->is_passing;

    $history->add_test_history( $Pass, $Fail );
    is_deeply $history->results, [
        $Pass, $Pass, $Fail
    ];
    is_deeply [$history->summary], [1, 1, 0];

    is $history->counter->get, 3;
    ok !$history->is_passing;

    # Try a history replacement
    $history->counter->set(2);
    $history->add_test_history( $Pass, $Pass );
    is_deeply [$history->summary], [1, 1, 1, 1];
}


# add_test_history argument checks
{
    my $history = $create_ok->();

    ok !eval {
        $history->add_test_history($Pass, { passed => 1 }, $Fail);
    };
    like $@, qr/takes Result objects/;
}


# should_keep_history
{
    my $history = $create_ok->();

    $history->should_keep_history(0);
    $history->add_test_history( $Pass );
    is $history->counter->get, 1;
    is_deeply $history->results, [];
}


# create() has its own Counter
{
    my $history = $CLASS->singleton;
    my $other   = $CLASS->create;

    $history->counter->set(22);
    is $other->counter->get, 0,         "create() comes with its own Counter";
}
