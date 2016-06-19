package Report3::XML;

##################################################
# MODULE: Report::XML
#	Модуль для формирования XML отчетов в госорганы
#
# Depends:
#	<XML::Compile::Schema> - CPAN модуль для работы с XSD схемами
#	<XML::LibXML> - CPAN модуль для работы с XML
#	<Encode> - CPAN модуль для работы с кодировками
#
##################################################

# CONSTRUCTOR: new
# 	Инициализирует объект
#
# Parameters: 
#	xsd - имя xsd-файла с описанием XML
#	writer - название (код) головного элемента XML для отчета
#	xsdhash - хеш с данными для XML-отчета
#
# Returns:
#	__PACKAGE__->{ xml } - содержание XML файла для отчета (undef, если есть ошибки) 
#	__PACKAGE__->{ status } - код результата
#		0 - содержание XML сформировано, 
#		1..n - ошибка
#	__PACKAGE__->{ err } - текст ошибки
#
sub new (%) {
	my $pkg = shift; # получаем имя класса
	my $self; { my %hash; $self = bless(\%hash, $pkg); }

	my (%args) = @_;

	$self->{ xsd }		= $args{ xsd } if defined $args{ xsd };
	$self->{ xsdhash }	= $args{ xsdhash } if defined $args{ xsdhash };
	$self->{ writer }	= $args{ writer } if defined $args{ writer };
	if (
		(not defined $self->{ xsd }) || (not defined $self->{ xsdhash }) || (not defined $self->{ writer })
	) {

		$self->{ status } = 1;
		$self->{ err } = 'Неверный вызов модуля для создания XML-отчета.';
		warn ( __PACKAGE__.' - Have no all parameters for new():'.
			(( not defined $self->{ xsd } )		? ' xsd' : '').
			(( not defined $self->{ xsdhash } )	? ' xsdhash' : '').
			(( not defined $self->{ writer } )	? ' writer' : '')
		);
	    return $self; # прерываемся
	}

	$self->{ status } = 0;
    return $self;
}

# FUNCTION: prepare_XML
#	подготовка содержимого XML-файла по XSD-схеме 
#
# Returns:
#
sub prepare_XML () {
	$pkg = shift;

	eval { require XML::Compile::Schema };
	if($@){
		$pkg->{ status } = 2;
		$pkg->{ err } = 'Не найден модуль компиляции схемы XSD-отчета.';
		warn 'XSD compilation module not found: XML::Compile::Schema / Error: '.$@;
		return;
	};

	my $schema = XML::Compile::Schema->new;

	foreach ( @{$pkg->{ xsd }} ) {
		$schema->importDefinitions( $_ );
	}

	my $write;
	eval { $write = $schema->compile( WRITER => $pkg->{ writer }, use_default_namespace => 1 ); };

	if($@){
		$pkg->{ status } = 3; 
		$pkg->{ err } = 'Не могу скомпилировать данные для XML-отчета: '.$@;
		warn(__PACKAGE__.' - Can not to compile XSD schema: '.$@);
		return;
	}

	use XML::LibXML;
	my $doc = XML::LibXML::Document->new('1.0', 'windows-1251');

	my $xml;
	eval{ $xml = $write->($doc, $pkg->{ xsdhash } );};  
	if($@){
		$pkg->{ status } = 4; # код ошибки = 1, не могу сформировать данные для XML
		$pkg->{ err } = 'Не могу разместить имеющиеся данные в XML-отчете. Ошибка: '.$@->{message}->toString();
#		warn( __PACKAGE__.' - Can not to write data to XML: '.$@->{message}->toString() );
		return;
	}

	$doc->setDocumentElement($xml);

	$pkg->{ xml } = $doc->toString(1); # содержание XML файла для отчета

	no XML::LibXML;
	no XML::Compile::Schema;

	$pkg->{ result } = 0; # код ошибки = 0, данные для XML успешно сформированы

}

1;