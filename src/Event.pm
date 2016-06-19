package Report3::Event;

##################################################
# MODULE: Report::Event
#	Модуль для работы с событиями при формировании отчетов
#
# Depends:
#	<File::Copy::Recursive> - CPAN модуль для работы с папками и файлами (копировать, очистить, создать)
#	<Time::Local> - CPAN модуль для работы со временем и датой (используется для преобразования даты в количество секунд с начала эпохи (1.1.1900) )
#
#
##################################################

# constant: ETALON
# 	код группы и поля для проверки, регулярные выражения для проверки поля, название поля для вывода ошибки.
#
use constant ETALON => {
	orginfo	=>	{
		fssregnum		=> ['^\d{10}$','ФСС: Регистрационный номер страхователя'],
		fsskodpodch		=> ['^\d{4}[1,2,3]$','ФСС: Код подчиненности'],
		fsstarifossnspz	=> ['^\d{1,2}(\.\d)?$','ФСС: Страховой тариф от несчастных случаев'],

		pfrregnum		=> ['^\d{3}-\d{3}-\d{6}$','ПФР: Регистрационный номер страхователя'],

		inn				=> ['^(\d{10}|\d{12})$','ИНН организации'],
		kpp				=> ['^(0|\d{9})$','КПП организации (можно оставить пустым, если нет КПП)'],
		ogrn			=> ['^(\d{13}|\d{15})$','ОГРН'],
		orgphone		=> ['\d{10}','Телефон организации - это 10 цифр, без +7 или 8 в начале. Только цифры кода города и номера телефона.'],
		namefull	 	=> ['^(.)+$','Полное название организации'],

		okved			=> ['^\d{1,2}(\.\d{1,2})?(\.\d{1,2})?$','ОКВЭД'],

	},
	yur_address	=> {
		postindex		=> ['\d{6}','Юр.адрес: почтовый индекс'],
	}
};

# CONSTRUCTOR: new
# 	Инициализирует объект Event
#
# Parameters: 
#
# Returns:
#
#
sub new(%) {
	my $pkg = shift; # получаем имя класса
	my $self; { my %hash; $self = bless(\%hash, $pkg); }

	my (%args) = @_;

	$self->{ site }->{ dbh }	= $args{ dbh } if defined $args{ dbh };
	$self->{ site }->{ user }	= $args{ user } if defined $args{ user };
	$self->{ site }->{ cfg }	= $args{ cfg } if defined $args{ cfg };

	# очищаем число номера события от возможных искажений
	if ( defined $args{ event } ) {
		$args{ event } =~ s/\D+//gis;
	}
	$self->{ site }->{ event }	= $args{ event } || 0;

	if ( defined $self->{ site }->{ cfg }->{ env }->{ USER_PATH } ) {

		# определяем отдельную переменную внутри класса,
		# чтобы можно было сослаться на нее при закрытии класса (для очистки временных папок)
		$self->{ userpath } = $self->{ site }->{cfg}->{env}->{USER_PATH}.'/'.$self->{ site }->{user}->{idorgdetails};
	}

	# для краткости обращения - сохраним адрес
	my $site = \$self->{ site };

	if (
		(not defined $$site->{ dbh }) || (not defined $$site->{ user }) || 
		(not defined $$site->{ cfg }) || (not defined $$site->{ event }) 
	) {
		$self->{ status } = 1;
		$self->{ err } = 'Неверный вызов события.';
		warn ( __PACKAGE__.' - Has no all parameters for new():'.
			(( not defined $$site->{ dbh } )	? ' dbh' : '').
			(( not defined $$site->{ cfg } )	? ' cfg' : '').
			(( not defined $$site->{ user } )	? ' user' : '').
			(( $$site->{ event } == 0 )			? ' event' : '')
		);

	    return $self;
	}

	# Variable: MyReport->{event}
	# 	хеш данных о событии, по которому создается отчет
	#
	#	MyReport->{event}->{idevents} - id события (передается входным параметром <event>)
	#	MyReport->{event}->{...} - другие данные из таблицы _events_list_
	#
	my $event = {};
	$self->{event} = $event;
	%$event = (
		idevents	=> $self->{ site }->{ event },
	);

	# получаем информацию о событии
	if (
		( ref $self->{ site }->{ dbh } eq 'DBI::db' ) && 
		( defined $self->{ site }->{user}->{idorgdetails} ) && 
		( $self->{ site }->{user}->{idorgdetails} > 0 ) &&
		( $self->{event}->{idevents} > 0 )
	) {
		my $hr;

		($hr) = $self->{ site }->{dbh}->selectrow_hashref("SELECT * FROM events_list WHERE idevents = '$self->{event}->{idevents}'");
		if ( defined $hr->{idevents} ) {
			%{$event} = ( %{$event}, %{$hr} );
			my $step_check = $self->_check_previous_report(); # проверяем, сформирован ли отчет. После выполнения статус и ошибка могут измениться.

			if ( $step_check->{ status } != 0 ) {
				$self->{status} = $step_check->{ status };
				$self->{err} = $step_check->{ err };
				return $self; # досрочное завершение инициализации объекта
			}

		} else {
			# если запрошенный idevent отсутствует в БД, то его не должно быть.
			$self->{event}->{idevents} = undef;
			# шаг пройден с ошибкой, запрет двигаться дальше
			$self->{status} = 1;
			$self->{err} = 'событие отсутствует в базе данных';

			return $self; # досрочное завершение инициализации объекта
		}
	} else {
		$self->{ status } = 2;
		$self->{ err } = 'Не могу прочитать информацию о событии.';
		warn ( __PACKAGE__.' - Can not read event info from DB:'.
			(( ref $self->{ site }->{ dbh } ne 'DBI::db' )					? ' no_DBI_connection' : '').
			(( not defined $self->{ site }->{ user }->{ idorgdetails } )	? ' not_defined_idorgdetails' : ''). 
			(( defined $self->{ site }->{ user }->{ idorgdetails } && 
				( $self->{ site }->{ user }->{ idorgdetails } < 1 ) )		? ' wrong_idorgdetails' : '').
			(( $self->{ event }->{ idevents } < 1 )							? ' wrong_idevents' : '')
		);
	    return $self;
	}

	if ( defined $self->{ site }->{ cfg }->{ env }->{ USER_PATH } ) {

		# Проверяем наличие пользовательских каталогов. Если надо - создаем!

		use File::Copy::Recursive;

		my $path_to_user_folder = $self->{ site }->{cfg}->{env}->{USER_PATH}.'/'.$self->{ site }->{user}->{idorgdetails};

		if ( not -e $path_to_user_folder ) {
			File::Copy::Recursive::pathmk( $path_to_user_folder );
		}	

		if ( not -e $path_to_user_folder.'/xl-sheets' ) {
			File::Copy::Recursive::pathmk( $path_to_user_folder.'/xl-sheets' );
		} else {
			File::Copy::Recursive::pathempty( $path_to_user_folder.'/xl-sheets' );
		}	

		if ( not -e $path_to_user_folder.'/tmp' ) {
			File::Copy::Recursive::pathmk( $path_to_user_folder.'/tmp' );
		} else {
			File::Copy::Recursive::pathempty( $path_to_user_folder.'/tmp' );
		}

		if ( not -e $path_to_user_folder.'/XML' ) {
			File::Copy::Recursive::pathmk( $path_to_user_folder.'/XML' );
		}

		no File::Copy::Recursive;

	} else {
		$self->{status} = 3;
		$self->{err} = 'Не могу подготовить место для создания Excel-файла с отчетом.';
		warn(__PACKAGE__." - Event don't know abut cfg->env->USER_PATH parameter");
		return $self; # досрочное завершение инициализации объекта
	}

	$self->_get_datenow; # дополняем объект формами представления текущей даты

	$self->{status} = 0;
	$self->{err} ='';
    return $self;
}

# FUNCTION: _check_previous_report
#	Проверяем наличие сформированного отчета.
#
# Returns:
#   {status} - статус: 0 - нет ошибок, 1..n - есть ошибка
#	{err}	- содержание ошибки
#
sub _check_previous_report() {
	my $self = shift;

	my $step_check = {};	# указатель на хеш со статусом работы проверки

	my ($ideventlog, $eventdatefact, $eventfilename, $eventfilenamexml) = $self->{ site }->{ dbh }->selectrow_array(
		"SELECT ideventslog, eventdatefact, eventfilename, eventfilenamexml FROM events_log ".
		"WHERE events_list_idevents = $self->{event}->{idevents} ".
		"AND orgdetails_idorgdetails = $self->{site}->{user}->{idorgdetails}"
	);
	if (defined $ideventlog) {

		my $ExcelTargetFile = $self->{site}->{cfg}->{env}->{USER_PATH}.'/'.$self->{site}->{user}->{idorgdetails}.'/'.$eventfilename;
		my $XMLTargetFile = $self->{site}->{cfg}->{env}->{USER_PATH}.'/'.$self->{site}->{user}->{idorgdetails}.'/XML/'.$eventfilenamexml;

		if ( (defined $eventfilename) && (-e $ExcelTargetFile) ) { # Запись в логах об отчете есть. Если файл тоже есть - выходим с ошибкой.
			$step_check->{status} = 1;
			$step_check->{err} = 'Отчет уже был сформирован ранее, '.$eventdatefact.'.<br>Скачать: ';
			if ( $eventfilename ) {
				$step_check->{err} .= '<li>в формате Excel - <a href="/cgi-bin/u/api/event/report/excel/'.$self->{event}->{idevents}.'" target="_blank">'.$eventfilename.'</a></li>';
			}
			if ( $eventfilenamexml ) {
				$step_check->{err} .= '<li>в формате XML - <a href="/cgi-bin/u/api/event/report/xml/'.$self->{event}->{idevents}.'" target="_blank">'.$eventfilenamexml.'</a></li>';
			}

			return $step_check; # досрочное завершение проверки
		} else { # Запись в логах об отчете есть. Но файл потеряли. 
			# Значит удаляем запись из БД и можно заново сформировать отчет.

			eval {
				$self->{ site }->{ dbh }->do("DELETE FROM events_log WHERE events_list_idevents = $self->{event}->{idevents} AND orgdetails_idorgdetails = $self->{site}->{user}->{idorgdetails}");
			};
			if ($@ || $self->{ site }->{ dbh }->errstr) {
				# откат внутри eval, чтобы ошибка отката не привела к завершению работы сценария
				eval { $self->{ site }->{ dbh }->rollback (); };

				$step_check->{status} = 2;
				$step_check->{err} = 'Файл с отчетом отсутствует. Не могу удалить старую запись о ранее сформированном отчете.';
				warn( 'Report::Event - Report file present, but log record has not deleted. Err:'.$@.'; '.$self->{ site }->{ dbh }->errstr ) ;
				return $step_check; # досрочное завершение проверки
			} else # все отработало без ошибок
			{
				$self->{ site }->{ dbh }->commit(); # фиксируем изменения в БД
				$step_check->{status} = 0;
			}
		}
	} else {
		# событие не найдено, можно формировать отчет
		$step_check->{status} = 0;
	}

	return $step_check;
}

# FUNCTION: _get_datenow
#	формирует элемент datenow внутри элемента event объекта с датой СЕГОДНЯ в разных форматах
#
#
# Returns:
#
sub _get_datenow() {
	$pkg = shift;

	my @datenow_arr = ( 0,0,0, (localtime())[3,4,5] ); # массив с информацией о текущей дате (время = 00:00:00)
	$datenow_arr[5] += 1900;

	use Time::Local qw(timelocal);
	my $datenow_int = timelocal( @datenow_arr ); # преобразовываем дату в количество секунд с начала эпохи (1.1.1900) 
	no Time::Local;

	# constant: OFMONTH_TXT_RU
	# 	названия месяцев, пример: "марта"
	#
	use constant OFMONTH_TXT_RU => ('января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря');

	$pkg->{event}->{ datenow } = {
			# сегодня в формате Excel ( количество дней от 01.01.1900 )
			datenowx	=>	int( $datenow_int/24/60/60+25569 + 1 ),
			# сегодня в формате DDMMGGGG
			datenowddmmyyyy	=>	sprintf( "%02d%02d%4d", $datenow_arr[3], $datenow_arr[4]+1, $datenow_arr[5] ),
			# сегодня в формате yyyy-MM-dd
			datenowsql		=>	sprintf( "%4d-%02d-%02d", $datenow_arr[5], $datenow_arr[4]+1, $datenow_arr[3] ),
			# сегодня DD
			datenowday	=>	sprintf( "%02d", $datenow_arr[3] ),
			# сегодня MM
			datenowmonth =>	sprintf( "%02d", $datenow_arr[4]+1 ),
			# сегодня MM
			datenowmonthtext =>	sprintf( "%s", (OFMONTH_TXT_RU)[ $datenow_arr[4] ] ),
			# сегодня GGGG
			datenowyear	=>	sprintf( "%04d", $datenow_arr[5] ),
			# сегодня GG
			datenowyear2 =>	sprintf( "%02d", $datenow_arr[5]-2000 ),
	};

	return $pkg;
}

# FUNCTION: _check_etalon
#	ПРОВЕРКА данных с эталоном на соответствие формату данных
#
# Arguments:
#	$site - массив данных объекта site для проверки
#	$chklist - хеш с кодом группы и списком полей для проверки вида, например:
#>	{
#>		orginfo	=> [ 'pfrregnum', 'inn', 'kpp', 'ogrn', 'orgphone', 'namefull', 'okved' ],
#>		yur_address	=> [ 'postindex' ],
#>	}
#
# Returns:
#   {status} - статус: 0 - нет ошибок, 1..n - есть ошибка
#	{err}	- содержание ошибки
#
sub check_etalon($$) {
	my $pkg = shift;
	my $site = shift;
	my $chkList = shift;

	my $step_check = {};	# указатель на хеш со статусом работы проверки
	my $result = {};		# указатель на хеш для сбора результатов проверки по каждой группе и полю
	
	my @out = ();
	foreach my $group ( keys %{ $chkList } ) {
		if ( defined ETALON()->{$group} ) {
			foreach my $field ( @{ $chkList->{ $group } } ) {
				if ( defined ETALON()->{$group}->{$field} ) {
					my ( $regexp, $err ) = @{ETALON()->{$group}->{$field}};
					$result->{$group}->{$field} = ( defined $site->{$group}->{$field} && ( $site->{$group}->{$field} =~ /$regexp/ ) ) ? 1 : 0;
					push @out, $err if ($result->{$group}->{$field} == 0);
				} else {
					$step_check->{status} = 2;
					$step_check->{err} = 'При проверке данных не найдено поле '.$field;
					warn __PACKAGE__.' - check_etalon() error: not found field '.$field;
					return $step_check; # досрочное завершение проверки
				}
			}
		} else {
			$step_check->{status} = 1;
			$step_check->{err} = 'При проверке данных не найдена группа '.$group;
			warn __PACKAGE__.' - check_etalon() error: not found group '.$group;
			return $step_check; # досрочное завершение проверки
		}
	}

	# если индекс (порядковый номер) последнего элемента массива == -1, значит массив пустой (в нем нет элементов)
	$step_check->{status} = ( $#out == -1 ) ? 0 : 3; # устанавливаем статус по количеству ячеек в массиве
	$step_check->{err} = ( $#out == -1 ) ? '' : 'Не заполнены или неверно заполнены поля в Настройках: '.join(', ',@out); # формируем текст ошибки
	
	return $step_check;
}

# FUNCTION: log_event
#	сохраняет в логах запись о созданном отчете
#
sub log_event() {
	my $pkg = shift;

	eval {
		my $sth = $pkg->{ site }->{ dbh }->prepare("INSERT INTO events_log SET eventdatefact = NOW(), eventfilename = ?, eventfilenamexml = ?, events_list_idevents = ?, orgdetails_idorgdetails = ?");
		$sth->execute( 
			$pkg->{ event }->{ filename }->{ excel }, $pkg->{ event }->{ filename }->{ xml }, 
			$pkg->{ event }->{ idevents }, $pkg->{ site }->{ user }->{ idorgdetails } 
		);
	};
	if ($@ || $pkg->{ site }->{ dbh }->errstr) {
		$pkg->{status} = 1;
		warn( 'Report::Event - Can not to write the report log event. Err: '.$@.'; '.$pkg->{ site }->{ dbh }->errstr);
		$pkg->{err} = 'Не могу записать результат подготовки отчета в базу данных.';
		# откат внутри eval, чтобы ошибка отката не привела к завершению работы сценария
		eval { $pkg->{ site }->{ dbh }->rollback (); };
	} else # все отработало без ошибок
	{
		$pkg->{ site }->{ dbh }->commit(); # фиксируем изменения в БД
		$pkg->{ status } = 0;
	}
}

# FUNCTION: is_xsd_files_presents
#	Проверяет, существуют ли файлы на диске (в частности, XSD-схемы)
#
# Returns:
#	0 - файлы недоступны
#	1 - файлы доступны
sub is_xsd_files_presents($$) {
	my $pkg = shift;
	my $pathlib = shift;
	my $filesref = shift;

	foreach ( @{ $filesref } ) {
		return 0 if ( not -e $pathlib.'/'.$_ );
	}

	return 1;

}


# FUNCTION: DESTROY
#	удаляет класс из памяти
#	Заодно удаляет созданные при формировании EXCEL-отчета временные файлы из папок:
#	- /3sec-userfiles/{orgId}/tmp и 
#	- /3sec-userfiles/{orgId}/xl-sheets
#
sub DESTROY {
	my $self = shift;

	if ( defined $self->{ userpath } ) {

		use File::Copy::Recursive;

		# очищаем папку с временными файлами
		if ( -e $self->{ userpath }.'/tmp' ) {
			my $result = File::Copy::Recursive::pathempty( $self->{ userpath }.'/tmp' );
			if ( $result != 1 ) {
				warn(__PACKAGE__." - Can't make folder ".$self->{ userpath }."/tmp empty, pathempty result = ".$result);
			}
		};

		# очищаем папку с заготовкой отчета в excel
		if ( -e $self->{ userpath }.'/xl-sheets' ) {
			my $result = File::Copy::Recursive::pathempty( $self->{ userpath }.'/xl-sheets' );
			if ( $result != 1 ) {
				warn(__PACKAGE__." - Can't empty ".$self->{ userpath }."/xl-sheets folder. pathempty result = ".$result);
			}
		};

		no File::Copy::Recursive;

	} else {
		warn(__PACKAGE__." - has losed userpath hash to make temporary folders empty");
	}
}

1;