### //////////////////////////////////////////////////////////////////////////
#
#	TOP
#

=head1 NAME

SML::Document - Aggregate SML::Block/s and feed it into SML::Template

=cut

#------------------------------------------------------
# (C) Daniel Peder & Infoset s.r.o., all rights reserved
# http://www.infoset.com, Daniel.Peder@infoset.com
#------------------------------------------------------

###													###
###	size of <TAB> in this document is 4 characters	###
###													###

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: package
#

	package SML::Document;


### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: version
#

	use vars qw( $VERSION $VERSION_LABEL $REVISION $REVISION_DATETIME $REVISION_LABEL $PROG_LABEL );

	$VERSION           = '0.10';
	
	$REVISION          = (qw$Revision: 1.1 $)[1];
	$REVISION_DATETIME = join(' ',(qw$Date: 2004/05/19 21:03:37 $)[1,2]);
	$REVISION_LABEL    = '$Id: Document.pm_rev 1.1 2004/05/19 21:03:37 root Exp root $';
	$VERSION_LABEL     = "$VERSION (rev. $REVISION $REVISION_DATETIME)";
	$PROG_LABEL        = __PACKAGE__." - ver. $VERSION_LABEL";

=pod

 $Revision: 1.1 $
 $Date: 2004/05/19 21:03:37 $

=cut


### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: debug
#

	use vars qw( $DEBUG ); $DEBUG=0;
	

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: constants
#

	# use constant	name		=> 'value';
	

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: modules use
#

	require 5.005_62;

	use strict                  ;
	use warnings                ;
	
	use	SML::Parser				;
	use	SML::Block				;
	use	SML::Template			;
	use	SML::Builder			;
	
	use	IO::File::String		;
	use	File::Spec				;
	

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: methods
#

=head1 METHODS

=over 4

=cut


### ##########################################################################

=item	new

 $sml_doc = new SML::Document();
 
=cut

### --------------------------------------------------------------------------
sub		new
### --------------------------------------------------------------------------
{
	my( $proto ) = @_;
	bless {}, ref( $proto ) || $proto;
}


### ##########################################################################

=item	add_block ( $sml [, $priority ] )

Add sections from B<$sml> block into this document's sections collection.
If there are already existing sections with same name, 
then the new section content will replace the old one 
only if the new one got higher B<$priority>.

=cut

### --------------------------------------------------------------------------
sub		add_block
### --------------------------------------------------------------------------
{
	my( $self, $sml, $priority )=@_;
	
	my	$block	= new SML::Block();
		$block->parse( $sml );
		
	$priority	||= 0;
	
	for my $section_name ( $block->get_sections_names())
	{
		next 
		if	exists( $self->{section_priority}{$section_name} ) 
		&&	$self->{section_priority}{$section_name} >= $priority;
		
		$self->{section_priority}{$section_name}	= $priority;
		$self->{section}{$section_name}				= $block->get_section_arrayref( $section_name );
	}
}


### ##########################################################################

=item	add_block_file ( $filename [, $priority ] )

Read B<$filename>, then B<< $self->add_block( $sml ) >>. Return undef unless
any data read.

=cut

### --------------------------------------------------------------------------
sub		add_block_file
### --------------------------------------------------------------------------
{
	my( $self, $filename, $priority )=@_;

		$filename	= $self->get_abs_filename( $filename );
	my	$block_sml = IO::File::String->new( "< $filename" )->load;
	
		unless( $block_sml )
		{
			warn "cant read block file '$filename'";
			return undef;
		}
	
		$self->add_block( $block_sml, $priority );
}




### ##########################################################################

=item	set_template ( $template_name, $sml )

Activate SML::Template object B<$template_name> parsing B<$sml> string data.

Why to have multiple templates? The idea is to have one template for
each content-type to be build-up from this document. So we could setup
one template for text/plain, one for text/html. Feeding each one will produce
the right formatted output. Well there are some limitations, but we'll try
to solve them later.

=cut

### --------------------------------------------------------------------------
sub		set_template
### --------------------------------------------------------------------------
{
	my( $self, $template_name, $sml )=@_;
	
	my	$template	= new SML::Template();
		$template->parse( $sml );
	$self->{template_default_name}		= $template_name unless exists $self->{template}{DEFAULT}; # TODO: method able to change-or-specify default template
	$self->{template}{$template_name}	= $template;
}


### ##########################################################################

=item	set_template_file ( $template_name, $filename )

Read B<$filename>, then B<< $self->set_template( $template_name, $sml ) >>. 
Return undef unless any data read.

=cut

### --------------------------------------------------------------------------
sub		set_template_file
### --------------------------------------------------------------------------
{
	my( $self, $template_name, $filename )=@_;

		$filename	= $self->get_abs_filename( $filename );
	my	$template_sml = IO::File::String->new( "< $filename" )->load;
	
		unless( $template_sml )
		{
			warn "cant read template file '$filename'";
			return undef;
		}
	
		$self->set_template( $template_name, $template_sml );
}


### ##########################################################################

=item	get_sections_names ( )

Get names of all document sections. In array context return array, otherwise
 arrayref.

=cut

### --------------------------------------------------------------------------
sub		get_sections_names
### --------------------------------------------------------------------------
{
	my( $self )=@_;
	
	wantarray ? keys( %{$self->{section}} ) : \keys( %{$self->{section}} );

}



### ##########################################################################

=item	feed_template ( [ $template_name ] )

Feed block data using parsed|unparsed sml template. The template
is selected by B< $template_name > or by B< $self->{template_default_name} >
which is set as first template parsed (this functionality should be extended, see TODO).

=cut

### --------------------------------------------------------------------------
sub		feed_template
### --------------------------------------------------------------------------
{
	my( $self, $template_name )=@_;
	
	$template_name	||= $self->{template_default_name};
	return undef unless exists $self->{template}{$template_name};
	my	$template	= $self->{template}{$template_name};

	for my $section_name ( $self->get_sections_names )
	{
		my $token_name	= $section_name;
		my $token_value	= SML::Builder->build( $self->{section}{$section_name} );
		$template->set_token_value( $token_name, $token_value );
	}

	$template->build();
}


### ##########################################################################

=item	base_dir ( [ $dir ] )

Explicitly set base dir path.

=cut

### --------------------------------------------------------------------------
sub		base_dir
### --------------------------------------------------------------------------
{
	my( $self, $dir )=@_;
	
	$self->{config_base_dir}	||= File::Spec->rel2abs( $dir || '.' );
}



### ##########################################################################

=item	get_abs_filename ( $filename )

Get absolute filename.

=cut

### --------------------------------------------------------------------------
sub		get_abs_filename
### --------------------------------------------------------------------------
{
	my( $self, $filename )=@_;

	File::Spec->rel2abs( $filename, $self->base_dir() );
}



### ##########################################################################

=item	init_config_file ( $filename )

Read and parse document config from B<$filename>.

=cut

### --------------------------------------------------------------------------
sub		init_config_file
### --------------------------------------------------------------------------
{
	my( $self, $filename )=@_;

		$filename	= $self->get_abs_filename( $filename );
	my	$config_sml = IO::File::String->new( "< $filename" )->load;
	
		unless( $config_sml )
		{
			warn "cant read config file '$filename'";
			return undef;
		}
	
		$self->init_config( $config_sml );
}



### ##########################################################################

=item	init_config ( $config_sml )

Parse config string, then initialize each of its recognizable parts.

=cut

### --------------------------------------------------------------------------
sub		init_config
### --------------------------------------------------------------------------
{
	my( $self, $config_sml )=@_;

	my	$config	= SML::Parser->parse( $config_sml );
	for my $item	( @$config )
	{
		next unless 
				($item->[0] eq 'E')									# element
			&&	($item->[1] eq '!')									# processing instruction
			&&	($item->[2] =~ /^config\.(block|template)$/ios )	# tagname
		;
		
		my	$type	= $1; 											# eg. ['block'|'template']
		my	$attr	= SML::Parser->parse_attributes( $item->[3] );	# note: $attr->{attr_name} = [ 'attrvalue1', 'attrvalue2', ... ]
		
		if(		'block' eq $type )
		{
			my	$filename	= $attr->{file}[0];		next unless $filename;
			my	$priority	= $attr->{priority}[0];
			$self->add_block_file( $filename, $priority );
		}
		elsif(	'template' eq $type )
		{
			my	$filename	= $attr->{file}[0];		next unless $filename;
			my	$alias		= $attr->{alias}[0];	next unless $alias;
			$self->set_template_file( $alias, $filename );
		}
	}
}







=back

=cut


1;

__DATA__

__END__

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: TODO
#

=head1 TODO	

=head2 set_template()

method-or-mechanism able to change-or-specify default template

=cut
