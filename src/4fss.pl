#!/usr/bin/perl -w

use strict;

# File: 4fss.pl
#	скрипт подготовки и формирования отчета 4-ФСС
#
# See also:
#
use CGI;

use lib '../lib';
use MyAngel;
use Encode;  # decode_utf8, т.к. XML в формате win1251

use vars qw($q); 

my $q = new CGI;

# Variable: $site
# указатель на класс MyAngel
#
my $site = MyAngel->new( cgi => $q, tmpl => 1, tmplfile => $ENV{DOCUMENT_ROOT}.'/pathtotmpl/4fss.tmpl' );

$site->tmpl_put( pagename => "Формируем отчет 4-ФСС");

# Информируем о номере страницы в справке
$site->tmpl_put( helpId => '3-reportdo' );

# Variable: $user
# указатель на MyAngel->{user}
#
my $user =  $site->{user};

# Variable: $dbh
# указатель на MyAngel->{dbh}
#
my $dbh = $site->{dbh};

if ( $site->{ access }->{ granted } ) {

	# основная процедура. Чуто что не так - выходит с кодами ошибки
	my $ready = _processing();

	# передаем в шаблон переменные для отображения результата выполнения шагов (иконки, ошибки...)
	foreach my $key ( keys %$ready ) {
		$site->tmpl_put( 'ready_'.$key.'_'.$ready->{$key}->{status} => 1 );
		$site->tmpl_put( 'ready_'.$key.'_err' => $ready->{$key}->{err} );
	}

}

# выводим HTTP-заголовок и все переменные tmpl
$site->tmpl_show();

sub _processing {
	my $ready; # сюда будем сохранять результаты работы процессинга (статус и ошибки)

	my $idevents = $q->param('event') || undef; # какое событие нужно создать?

	my $event; # будущий объект событий
	eval { require Report3::Event };
	if($@){
		warn 'Report module not found: Report3::Event / Error: '.$@;
		$ready->{step0}->{status} = 1;
		$ready->{step0}->{err} = 'Не найден модуль определения события.';
		return $ready;
	} else {
		$event = Report3::Event->new( dbh => $dbh, user => $user, event => $idevents, cfg => $site->{ cfg } );

		if ( $event->{ status } != 0 ) {
			$ready->{ step0 }->{ status } = $event->{ status };
			$ready->{ step0 }->{ err } = $event->{ err };
			return $ready;
		} else {
			$ready->{ step0 }->{ status } = 0; # можем двигаться дальше
		}
	}

	# Шаг 0: Подключаем класс для подготовки отчета 4-ФСС
	#
	my $rep; # будущий объект отчета
	eval {	require Report3::FSS::4fss; };
	if($@){
		warn 'Report module not found: Report::FSS::4fss / Error: '.$@;
		$ready->{step0}->{status} = 1;
		$ready->{step0}->{err} = 'Не найден модуль для подготовки отчета.';
		return $ready;
	} else {
		$ready->{step0}->{status} = 0; # можем двигаться дальше
		$rep = Report3::FSS::4fss->new();
	}

	# Шаг 1: проверка корректности исходных данных для формирования отчета.
	#

	# Шаг 1.1.: Чтение исходных данных для отчета.
	#
	$site->get_orginfo; # читаем данные об организации
	$site->get_yur_address; # читаем информацию о юридическом адресе организации

	# Шаг 1.2.a: Данные об организации из модуля MyAngel для вывода информации в отчет
	$rep->{ repdata }->{ user } 	= $site->{ user };
	$rep->{ repdata }->{ orginfo }	= $site->{ orginfo };

	# Шаг 1.2.b: Данные об организации из модуля Event для вывода информации в отчет
	$rep->{ repdata }->{ event }	= $event->{ event };

	# Шаг 1.3.: формируем дополнительные переменные, необходимые для отчета
	$rep->{ repdata }->{ var } = _get_var( site => $site, event => $event );

	# Шаг 1.4.: проверяем каждое обязательное поле на корректность формата содержимого
	#
	my $checklist = {
		orginfo	=> [ 'fssregnum', 'fsskodpodch', 'fsstarifossnspz', 'inn', 'kpp', 'ogrn', 'orgphone', 'namefull', 'headfiof', 'headfioi', 'okved' ],
		yur_address	=> [ 'postindex', 'region', 'city', 'street', 'domtype', 'domnumber', 'korpustype', 'korpusnumber', 'roomtype', 'roomnumber' ],
	};

	$ready->{step1} = $event->check_etalon( $site, $checklist );
	return $ready if $ready->{step1}->{status} != 0;

	# Шаг 2: Генерация файла отчета в формате XML (для передачи по ТКС)
	#

	# Шаг 2.1. Вносим изменения в XML-заготовку отчета
	_prepare_data4xml ( xsdhash => $rep->{ xml }->{ xsdhash }, repdata => $rep->{ repdata } );

	# Шаг 2.2. Подключаем модуль работы с XML и XSD

	# проверяем, все ли файлы xsd схем доступны для чтения
	if ( $event->is_xsd_files_presents( $rep->{ xml }->{ xsd } ) ) {

		eval {	require Report3::XML; };
		if($@){
			warn 'XML module not found: Report3::XML / Error: '.$@;
			$ready->{step2}->{status} = 2;
			$ready->{step2}->{err} = 'Не найден модуль для подготовки отчета в формате XML.';
			return $ready;
		}

		my $xml = Report3::XML->new( 
			xsd		=> $rep->{ xml }->{ xsd }, 
			xsdhash	=> $rep->{ xml }->{ xsdhash }, 
			writer	=> $rep->{ xml }->{ writer } 
		);

		# Шаг 2.2.1. Формируем XML-отчет
		$xml->prepare_XML();			

		if ( $xml->{ status } == 0 && defined $xml->{ xml } ) {
			# Имя файла для 4-ФСС: <номер страхователя>_<расчетный год>_<отчетный квартал>.ef4
			my $userPath = $site->{cfg}->{env}->{USER_PATH}.'/XML';
			my $filename = $rep->{ xml }->{ xsdhash }->{TITLE}->{REG_NUM}.'_'.$rep->{ xml }->{ xsdhash }->{TITLE}->{YEAR_NUM}.'_'.$rep->{ repdata }->{ var }->{repperiod}.'.ef4';
			my $filenamefull = $userPath.'/'.$filename;
			if ( open(OUT,'> '.$filenamefull) ) {
				print OUT $xml->{ xml };
				close(OUT);
				$ready->{step2}->{status} = 0;
				$event->{ event }->{ filename }->{ xml } = $filename; # сохраняем имя файла события для дальнейшей записи в лог
			} else {
				warn "can't write 4fss file as XML";
				$ready->{step2}->{status} = 3;
				$ready->{step2}->{err} = 'Не могу записать данные XML в папку пользователя.';
				return $ready;
			}
		} else {
			warn $xml->{error};
			$ready->{step2}->{status} = 4;
			$ready->{step2}->{err} = $xml->{err};
			return $ready;
		}

	} else {
		warn '4fss report XSD file '.$rep->{ xml }->{ xsd }.' not found';
		$ready->{step2}->{status} = 1;
		$ready->{step2}->{err} = 'Не найдена XSD схема для подготовки отчета в формате XML.';
		return $ready;
	}

	# Шаг 3: Генерация файла отчета в формате Excel (для бумажной версии)
	#

	# Если модуль с привязкой данных к ячейкам Excel подключен.
	if ( $rep->{ xlsvar }->{ status } == 0 ) {

		eval { require Report3::Excel; };
		if($@){
			warn 'Excel module not found: Report3::Excel / Error: '.$@;
			$ready->{step2}->{status} = 1;
			$ready->{step2}->{err} = 'Не найден модуль для подготовки отчета в формате Excel.';
			return $ready;
		}

		my $excel = Report3::Excel->new( 
			tmpl			=> $rep->{ xlsvar }->{ tmpl }, 
			hashcell		=> $rep->{ xlsvar }->{ hash },
			hashdata		=> $rep->{ repdata },
			folder			=> $site->{cfg}->{env}->{USER_PATH},
			reportfilename	=> 'FSS-4FSS-'.$rep->{ repdata }->{ var }->{ god }.'-'.$rep->{ repdata }->{ var }->{ repperiod }, 
		);

		if ( $excel->{ status } == 0 ) {
			$ready->{step3}->{status} = $excel->{ status };

			$excel->create_excel_report(); # после вызова этой функции могут появиться новые статусы и коды ошибок

			$event->{ event }->{ filename }->{ excel } = $excel->{ filename }; # сохраняем имя файла события для дальнейшей записи в лог

			$ready->{step3}->{status} = $excel->{ status };
			$ready->{step3}->{err} = $excel->{ err };

		} else {
			$ready->{step3}->{status} = $excel->{ status };
			$ready->{step3}->{err} = $excel->{ err };
			return $ready;
		}
	}

	# Шаг 4: Записываем информацию о событии
	#
	$event->log_event(); # после вызова этой функции могут появиться новые статусы и коды ошибок
	$ready->{step4}->{status} = $event->{ status };
	$ready->{step4}->{err} = $event->{ err };
	
	# передаем в шаблон код события для скачивания
	$site->tmpl_put( idevents => $event->{event}->{idevents} );

	return $ready;
}

# FUNCTION: _get_var
#	готовим дополнительные переменные, необходимые для отчета
#
# Parameters: 
#	на вход подается хеш $site с данными из модуля MyAngel.pm
#
# Returns:
#	хеш с новыми переменными
#
sub _get_var {
	my (%args) = @_;
	my $site = defined $args{ site } ? $args{ site } : {};
	my $event = defined $args{ event } ? $args{ event } : {};

	my $var; # сюда копим переменные, которые будем возвращать

	# Код отчетного периода: (03 - I квартал, 06 - полугодие, 09 - 9 месяцев, 12 - год)
	# При представлении Расчета за 1-й квартал, полугодие, 9 месяцев и год заполняются только первые две ячейки поля «Отчетный период (код)». 
	$var->{repperiod} = unpack( "x5 a2", $event->{event}->{eventdatefinal} );

	# год отчетного периода
	$var->{god} = unpack( "x0 a4", $event->{event}->{eventdatefinal} );

	# готовим представление кода ОКВЭД
	$var->{okvedrow} = $site->{orginfo}->{okved}; #  в виде строки c точками, как она записана в настройках организации
	# в виде строки в 6 знаков для Excel
	$var->{okved} = $site->{orginfo}->{okved};
	$var->{okved} =~ s/\-/\./g;

	$var->{okved} .= '..'; # чтобы ОКВЭД из любого количества элементов обязательно можно было разделить на 3 группы
	$var->{okved} = sprintf( "%-2s%-2s%-2s", (split( '\.', $var->{okved}, 4 ))[0,1,2] ); # берем первые 3 группы, в 4-ю пишем остаток и забываем его

	# номер корректировки
	$var->{nomkorr} = '000';

	# номер обращения за выделением необходимых средств на выплату страхового обеспечения
	$var->{repperiodstrah} = '00';

	# среднесписочная численность работников
	$var->{srspchisl} = '0';
	# из них женщин
	$var->{woman} = '0';

	# ФИО руководителя
	$var->{headfio} = join(' ', $site->{orginfo}->{headfiof}, $site->{orginfo}->{headfioi}, $site->{orginfo}->{headfioo});

	# Достоверность и полноту сведений, указанных в настоящем расчете, подтверждаю
	# 1 - плательщик страховых взносов
	# 2 - представитель плательщика страховых взносов
	# 3 - правопреемник
	$var->{dostpodt} = '1';

	# Дата создания отчета в формате ddMMyyyy
	$var->{datenowddmmyyyy} = $event->{event}->{datenow}->{datenowddmmyyyy};

	# Дата создания отчета в формате числа Excel
	$var->{datenowx} = $event->{event}->{datenow}->{datenowx};

	# Прекращение деятельности ''
	$var->{prdeyat} = '';

	# Численность работающих инвалидов
	$var->{invalid} = 0;

	# Численность работников, занятых на работах с вредными и (или) опасными производственными факторами
	$var->{opasno} = 0;

	# Размер страхового тарифа с учетом скидки (надбавки) (%) (заполняется с двумя десятичными знаками после запятой)
	$var->{fsstarifossnspz2f} = sprintf( "%.2f", $site->{orginfo}->{fsstarifossnspz} );

	# Юридический адрес организации
	$var->{ya_postindex} = $site->{yur_address}->{postindex} || '';
	$var->{ya_row1} = $site->{yur_address}->{region} || '';	# субъект
	$var->{ya_row2} = $site->{yur_address}->{city} || '';	# город
	$var->{ya_row3} = $site->{yur_address}->{street} || '';	# улица
	$var->{ya_row4} = '';
	$var->{ya_row5} = '';
	$var->{ya_dom} = $site->{yur_address}->{domnumber} || '';
	$var->{ya_korpus} = $site->{yur_address}->{korpusnumber} || '';
	$var->{ya_room} = $site->{yur_address}->{roomnumber} || '';

	# TODO - Расширить типы НКО другими: 121 и 151 (уже есть клиенты)
	# Шифр страхователя: Группа 1 *XXX*/xx/xx
	#
	# 071 - Плательщики страховых взносов, применяющие основной тариф страховых взносов
	# 121 - Организации и индивидуальные предприниматели, применяющие упрощенную систему налогообложения, основной вид экономической деятельности которых установлен пунктом 8 части 1 статьи 58 Федерального закона от 24 июля 2009 г. N 212-ФЗ
	# 151 - СО НКО, зарегистрированные в установленном законодательством РФ порядке, применяющие упрощенную СНО и осуществляющие в соответствии с учредительными документами деятельность в области социального обслуживания населения, научных исследований и разработок, образования, здравоохранения, культуры и искусства(деятельность театров, библиотек, музеев и архивов) и массового спорта (за исключением профессионального), с учетом особенностей, установленных частями 5.1 - 5.3 статьи 58 Федерального закона от 24 июля 2009 г. N 212-ФЗ
	#
	$var->{shifrstrah1} = '071'; # Плательщики страховых взносов, применяющие основной тариф страховых взносов

	# Шифр страхователя: Группа 2 xxx/*XX*/xx. 
	# 
	# 01 - УСН, 
	# 02 - ЕНВД, 
	# 03 - ЕСХН, 
	# 00 - иные
	#
	if ( $site->{orginfo}->{sno} eq 'o' ) {
		$var->{shifrstrah2} = '00'; # иные плательщики
	} elsif ( $site->{orginfo}->{sno} eq 'r' || $site->{orginfo}->{sno} eq 'd') {
		$var->{shifrstrah2} = '01'; # Организации и индивидуальные предприниматели, применяющие упрощенную систему налогообложения, а также индивидуальные предприниматели, совмещающие применение упрощенной системы налогообложения, применяемой по основному виду деятельности, поименованному в пункте 8 части 1 статьи 58 Федерального закона от 24 июля 2009 г. N 212-ФЗ, и патентной системы налогообложения
	} else {
		#!!! если система налогообложения не ОСН и не УСН - мы не делаем этот отчет
	}

	# Шифр страхователя: Группа 3 xxx/xx/*XX*.
	# 
	# 01 - казенные и бюджетные организации, 
	# 00 - иные
	#

	if ( 
		$site->{orginfo}->{formtype} ne '9' &&	# 9 - Государственная корпорация
		$site->{orginfo}->{formtype} ne '10' &&	# 10 - Государственная компания
		$site->{orginfo}->{formtype} ne '12' &&	# 12 - Государственные, муниципальные учреждения
		$site->{orginfo}->{formtype} ne '13'		# 13 - Бюджетное учреждение                     
		) 
	{
		$var->{shifrstrah3} = '00'; # иные
	} else {
		# если форма организации казенная или бюджетная - мы не делаем этот отчет
	}

	return $var;
}

# FUNCTION: _prepare_data4xml
#	готовим переменные, необходимые для отчета в формате XML
#
# Parameters: 
#	на вход подается хеш _xsdhash_ с данными _repdata_
#
# Returns:
#	
#
sub _prepare_data4xml {
	my (%args) = @_;
	my $xsdhash = defined $args{ xsdhash } ? $args{ xsdhash } : {};
	my $repdata = defined $args{ repdata } ? $args{ repdata } : {};

	# Для тега TITLE
	#
	$xsdhash->{TITLE}->{QUART_NUM}	= sprintf("%d", $repdata->{ var }->{repperiod} ); # в XML нужно значение без ведущего нуля
	$xsdhash->{TITLE}->{YEAR_NUM}	= $repdata->{ var }->{god};
	$xsdhash->{TITLE}->{CRE_DATE}	= $repdata->{event}->{datenow}->{datenowsql};

	$xsdhash->{TITLE}->{NAME} 		= decode_utf8( $repdata->{ orginfo }->{ namefull } );
	$xsdhash->{TITLE}->{CEO} 		= decode_utf8( $repdata->{ var }->{ headfio } ); 
	$xsdhash->{TITLE}->{CADDR}		= decode_utf8( $repdata->{ yur_address }->{ as1string } );

	$xsdhash->{TITLE}->{REG_NUM}	= $repdata->{ orginfo }->{ fssregnum };
	$xsdhash->{TITLE}->{KPS_NUM}	= $repdata->{ orginfo }->{ fsskodpodch };
	$xsdhash->{TITLE}->{INN}		= $repdata->{ orginfo }->{ inn };
	$xsdhash->{TITLE}->{KPP}		= $repdata->{ orginfo }->{ kpp };
	$xsdhash->{TITLE}->{OGRN}		= $repdata->{ orginfo }->{ ogrn };

	$xsdhash->{TITLE}->{TaxType}	= $repdata->{ var }->{shifrstrah1};
	$xsdhash->{TITLE}->{TaxType2}	= $repdata->{ var }->{shifrstrah2};
	$xsdhash->{TITLE}->{TaxType3}	= $repdata->{ var }->{shifrstrah3};

	$xsdhash->{TITLE}->{NumCorr}	= $repdata->{ var }->{nomkorr};
	$xsdhash->{TITLE}->{NumDot}		= $repdata->{ var }->{repperiodstrah};

	$xsdhash->{TITLE}->{T1R1C2}		= $repdata->{ var }->{srspchisl};
	$xsdhash->{TITLE}->{T1R2C2}		= $repdata->{ var }->{woman};

	$xsdhash->{TITLE}->{PHONE}		= $repdata->{orginfo}->{orgphone};
	$xsdhash->{TITLE}->{EMAIL}		= $repdata->{orginfo}->{orgemail};

	$xsdhash->{TITLE}->{Upoln}		= $repdata->{ var }->{dostpodt};
	$xsdhash->{TITLE}->{LIKV}		= defined $repdata->{ var }->{prdeyat}  && $repdata->{ var }->{prdeyat} ne '' ? $repdata->{ var }->{prdeyat} : '0';

	# Для тега F4INF1
	#
	$xsdhash->{F4INF1}->{OKVED} 	= $repdata->{ var }->{ okvedrow };

	# Для тега F4INFO
	#
	$xsdhash->{F4INFO}->{OKVED} 	= $repdata->{ var }->{ okvedrow };
	$xsdhash->{F4INFO}->{RATE_MIS}	= $repdata->{orginfo}->{ fsstarifossnspz };

}
