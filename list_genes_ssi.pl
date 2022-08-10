BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use U2_modules::U2_users_1;
use U2_modules::U2_init_1;

#    This program is part of ushvam2, USHer VAriant Manager version 2
#    Copyright (C) 2012-2016  David Baux
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
#		This script is used to generate a list of genes to be included in an HTML menu (see HTML_DIR/fix_top.html)
#


my $config_file = U2_modules::U2_init_1->getConfFile();
my $config = U2_modules::U2_init_1->initConfig();
$config->file($config_file);# or die $!;
my $DB = $config->DB();
my $HOST = $config->HOST();
my $DB_USER = $config->DB_USER();
my $DB_PASSWORD = $config->DB_PASSWORD();

my $q = new CGI;

print $q->header(-type => 'text/html');



my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;



my $query = "SELECT DISTINCT (gene_symbol) as gene FROM gene ORDER BY gene_symbol;";

my $sth = $dbh->prepare($query);
my $res = $sth->execute();

while (my $result = $sth->fetchrow_hashref()) {
	print $q->start_li(), $q->start_em(), $q->a({'href' => "/perl/U2/genes.pl?name=$result->{'gene'}"}, $result->{'gene'}), $q->end_em(), $q->end_li()
}

exit;
