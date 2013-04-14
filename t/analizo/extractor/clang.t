package t::Analizo::Extractor::Clang;
use base qw(Test::Class);
use Test::More 'no_plan'; # REMOVE THE 'no_plan'

use strict;
use warnings;
use Data::Dumper;

use Analizo::Extractor::Clang;

my $extractor1 = Analizo::Extractor->load('Clang');
$extractor1->process('t/samples/animals/cpp');
my $animals = $extractor1->model;

my $extractor2 = Analizo::Extractor->load('Clang');
$extractor2->process('t/samples/hello_world/c');
my $hello_world = $extractor2->model;

print(Dumper($animals)) if $ENV{DEBUG};
print(Dumper($hello_world)) if $ENV{DEBUG};

sub cpp_classes : Tests {
  my @expected = qw(Animal Cat Dog Mammal);
  my @got = sort($animals->module_names);
  is_deeply(\@got, \@expected);
}

sub c_modules : Tests {
  my @expected = qw(hello_world main);
  my @got = sort($hello_world->module_names);
  is_deeply(\@got, \@expected);
}

sub inheritance : Tests {
  my @expected = qw(Animal);
  my @got = $animals->inheritance('Mammal');
  is_deeply(\@got, \@expected);

  @expected = qw(Mammal);
  @got = $animals->inheritance('Cat');
  is_deeply(\@got, \@expected);

  @got = $animals->inheritance('Dog');
  is_deeply(\@got, \@expected);
}

sub cpp_methods : Test {
  my @expected = qw(name);
  my $got = $animals->{modules}->{Animal}->{functions};
  is_deeply($got, \@expected);
}

# TODO C functions

# TODO - based on functionality from doxyparse extractor
#
# current module
# current filename
# function declaration
# variable declaration
# function call/uses
# variable references
# public members
# method LOC (?)
# method parameters
# method conditional paths
# abstract classes

# TODO from my head
# fully-qualified names (think namespaces)
# calls between C++ methods
# standalone functions in C++ code
# calls between C functions
# calls between C functions and C++ methods

__PACKAGE__->runtests;
