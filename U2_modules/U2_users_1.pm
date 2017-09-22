package U2_modules::U2_users_1;

#use DBI;
#use AppConfig qw(:expand :argcount); #in startup.pl
use U2_modules::U2_init_1;

#    This program is part of ushvam2, USHer VAriant Manager version 2
#    Copyright (C) 2012-2014  David Baux
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
#		object routines to manage patients

#not a real object class
#OO persistence is quite sophisticated for that purpose.
#using CGI session would probably be the best way of achieving a user management
#but I like the idea of doing it myself.
#major inconvenient: create a new user each time a cgi is loaded
#but as user login relies on apache, this should be ok



my $config_file = U2_modules::U2_init_1->getConfFile();
my $config = U2_modules::U2_init_1->initConfig();
$config->file($config_file);# or die $!;
my $DB = $config->DB();
my $HOST = $config->HOST();
my $DB_USER = $config->DB_USER();
my $DB_PASSWORD = $config->DB_PASSWORD();


my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;


#users in the hash table should correspond to users in htpasswd
#name	=>	[is_analyst, is_validator, is_referee]
#our $USERS  = {
#	'david' =>	[1, 1, 1],
#	'afr'	=>	[1, 1, 1],
#	'christel' =>	[1, 1, 1],
#	'thomas'	=>	[1, 0, 1],
#	'gema'	=>	[1, 1, 1],
#	'susana'	=>	[1, 0, 1],
#	'val'	=>	[1, 0, 1],
#	'vanessa'	=>	[1, 0, 1],
#	'ale'	=>	[1, 0, 1],
#	'najla'	=>	[0, 0, 0],
#};

sub new {
	my ($class) = shift;
	#return $ENV{REMOTE_USER};
	my $self = {name => $ENV{REMOTE_USER}};
	bless ($self,$class);
	return $self;
}

sub setName {
	my $self = shift;
	$self->{name} = $ENV{REMOTE_USER};
}
sub getName {
	my $self = shift;
	return $self->{name};
}

sub isAnalyst {
	my $self = shift;
	my $query = "SELECT * FROM valid_analyste WHERE analyste = '".$self->getName()."';";
	my $res = $dbh->selectrow_hashref($query);
	if ($res->{'analyste'} ne '') {return '1'}
	else {return '0'}
	#return $USERS->{$self->getName()}->[0];
}
sub isValidator {
	my $self = shift;
	my $query = "SELECT * FROM valid_validateur WHERE validateur = '".$self->getName()."';";
	my $res = $dbh->selectrow_hashref($query);
	if ($res->{'validateur'} && $res->{'validateur'} ne '') {return '1'}
	else {return '0'}
	#return $USERS->{$self->getName()}->[1];
}
sub isReferee {
	my $self = shift;
	my $query = "SELECT * FROM valid_referee  WHERE referee = '".$self->getName()."';";
	my $res = $dbh->selectrow_hashref($query);
	if ($res->{'referee'} ne '') {return '1'}
	else {return '0'}
	#return $USERS->{$self->getName()}->[2];
}

sub isAnalystToString {
	my $self = shift;
	if ($self->isAnalyst() == 1) {
		return "can analyse"
	}
	else {
		return "cannot analyse"
	}
}
sub isValidatorToString {
	my $self = shift;
	if ($self->isValidator() == 1) {
		return "can validate"
	}
	else {
		return "cannot validate"
	}
}
sub isRefereeToString {
	my $self = shift;
	if ($self->isReferee() == 1) {
		return "can referee"
	}
	else {
		return "cannot referee"
	}
}

sub getEmail {
	my $self = shift;
	my $query = "SELECT email FROM valid_analyste WHERE analyste = '".$self->getName()."';";
	my $res = $dbh->selectrow_hashref($query);
	if ($res->{'email'} ne '') {return $res->{'email'}}
}

1;