package Analizo::Extractor::Clang;

use strict;

use base qw(Analizo::Extractor);

use File::Basename;

use Clang;

sub new {
  my $package = shift;
  return bless { files => [], visited_nodes => { }, @_ }, $package;
}

sub actually_process($@) {
  my ($self, @input) = @_;

  my $index = Clang::Index -> new(0);
  my $is_c_code = 1;
  if (grep { $_ =~ /\.(cc|cxx|cpp)$/ } @input) {
    $is_c_code = 0;
  }

  for my $file (@input) {
    my $tunit = $index->parse($file);
    my $node = $tunit->cursor;
    $self->_visit_node($node, $is_c_code);
  }
}

sub _visit_node($$$) {
    my ($self, $node, $is_c_code) = @_;

    my $name = $node->spelling;
    my $kind = $node->kind->spelling;
    my ($file, $line, $column) = $node->location();

    # FIXME find other way of skipping nodes outside of the analyzed tree?
    if ($file =~ m/^\/usr/) {
        return;
    }

    if ($kind eq 'ClassDecl') {
      $self->model->declare_module($name);
      _find_children_by_kind($node, 'C++ base class specifier',
        sub {
          my ($child) = @_;
          my $superclass = $child->spelling;
          $superclass =~ s/class //; # FIXME should follow the reference to the actual class node instead
          if (! grep { $_ eq $superclass } $self->model->inheritance($name)) {
            $self->model->add_inheritance($name, $superclass);
          }
        }
      );
      _find_children_by_kind($node, 'CXXMethod',
        sub {
          my ($child) = @_;
          my $method = $child->spelling;
          $self->model->declare_function($name, $method, $method);
        }
      );
    }

    if ($is_c_code && $kind eq 'TranslationUnit') {
      my $module_name = basename($name);
      $module_name =~ s/\.\w+$//;
      $self->model->declare_module($module_name);
      _find_children_by_kind($node, 'FunctionDecl',
        sub {
          my ($child) = @_;
          my $function = $child->spelling;
          my ($child_file) = $child->location;
          return if ($child_file ne $name);
          $self->model->declare_function($module_name, $function, $function);
        }
      );
    }

    my $children = $node->children;
    foreach my $child(@$children) {
      $self->_visit_node($child);
    }
}

sub _find_children_by_kind($$$) {
  my ($node, $kind, $callback) = @_;
  for my $child (@{$node->children}) {
    if ($child->kind->spelling eq $kind) {
      &$callback($child);
    }
  }
}

1;
