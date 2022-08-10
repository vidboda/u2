package U2_modules::U2_init_1;

#use AppConfig qw(:expand :argcount); #in startup.pl
use File::Basename;

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
#		initiates config


##Replace ushvam2.config with the name of your config file
## ushvam2.config MUST BE IN THE SAME DIRECTORY THAN THE CALLING FILE

sub getConfFile {
	return dirname($ENV{SCRIPT_FILENAME}).'/ushvam2.config';
}

##Loads each variable

sub initConfig {
	return AppConfig->new(
		'U2HOST' => {ARGCOUNT => 1},
		'HOME' => {ARGCOUNT => 1},
		'HOME_IP' => {ARGCOUNT => 1},
		'PERL_SCRIPTS_HOME' => {ARGCOUNT => 1},
		'HTDOCS_PATH' => {ARGCOUNT => 1},
		'ABSOLUTE_HTDOCS_PATH' => {ARGCOUNT => 1},
		'TMP_DIR' => {ARGCOUNT => 1},
		'DALLIANCE_DATA_DIR_URI' => {ARGCOUNT => 1},
		'DALLIANCE_DATA_DIR_PATH' => {ARGCOUNT => 1},
		'REF_GENE_URI' => {ARGCOUNT => 1},
		'DATABASES_PATH' => {ARGCOUNT => 1},
		'EXE_PATH' => {ARGCOUNT => 1},
		'PYTHON_PATH' => {ARGCOUNT => 1},
		'PYTHON3_PATH' => {ARGCOUNT => 1},
		'JS_PATH' => {ARGCOUNT => 1},
		'JS_DEFAULT' => {ARGCOUNT => 1},
		'CSS_PATH' => {ARGCOUNT => 1},
		'CSS_DEFAULT' => {ARGCOUNT => 1},
		'DB' => {ARGCOUNT => 1},
		'HOST' => {ARGCOUNT => 1},
		'ADMIN_EMAIL' => {ARGCOUNT => 1},
		'ADMIN_EMAIL_DEST' => {ARGCOUNT => 1},
		'DB_USER' => {ARGCOUNT => 1},
		'DB_PASSWORD' => {ARGCOUNT => 1},
		'PATIENT_IDS' => {ARGCOUNT => 1},
		'PATIENT_FAMILY_IDS' => {ARGCOUNT => 1},
		'PATIENT_PHENOTYPE' => {ARGCOUNT => 1},
		'ANALYSIS_GRAPHS_ELIGIBLE' => {ARGCOUNT => 1},
		'ANALYSIS_NGS_DATA_PATH' => {ARGCOUNT => 1},
		'ANALYSIS_MISEQ_FILTER'	=> {ARGCOUNT => 1},
		'ANALYSIS_ILLUMINA_REGEXP' => {ARGCOUNT => 1},
		'ANALYSIS_ILLUMINA_PG_REGEXP' => {ARGCOUNT => 1},
		'ANALYSIS_ILLUMINA_WG_REGEXP' => {ARGCOUNT => 1},
		'PERL_ACCENTS' => {ARGCOUNT => 1},
		'SSH_RACKSTATION_LOGIN' => {ARGCOUNT => 1},
		'SSH_RACKSTATION_PASSWORD' => {ARGCOUNT => 1},
		'SSH_RACKSTATION_IP' => {ARGCOUNT => 1},
		'SSH_RACKSTATION_BASE_DIR' => {ARGCOUNT => 1},
		'SSH_RACKSTATION_PARTIAL_PATH' => {ARGCOUNT => 1},
		'SSH_RACKSTATION_MINISEQ_BASE_DIR' => {ARGCOUNT => 1},
		'SSH_RACKSTATION_NEXTSEQ_BASE_DIR' => {ARGCOUNT => 1},
		'SSH_RACKSTATION_MINISEQ_PARTIAL_PATH' => {ARGCOUNT => 1},
		'SSH_RACKSTATION_FTP_BASE_DIR' => {ARGCOUNT => 1},
		'SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR' => {ARGCOUNT => 1},
		'SSH_RACKSTATION_NEXTSEQ_FTP_BASE_DIR' => {ARGCOUNT => 1},
		'CLINICAL_EXOME_SHORT_BASE_DIR' => {ARGCOUNT => 1},
		'CLINICAL_EXOME_BASE_DIR' => {ARGCOUNT => 1},
		'CLINICAL_EXOME_ANALYSES' => {ARGCOUNT => 1},
		'CLINICAL_EXOME_METRICS_SOURCES' => {ARGCOUNT => 3},
		'RS_BASE_DIR' => {ARGCOUNT => 1},
		'EMAIL_SMTP' => {ARGCOUNT => 1},
		'EMAIL_PORT' => {ARGCOUNT => 1},
		'EMAIL_PASSWORD' => {ARGCOUNT => 1},
		'EMAIL_CLASS' => {ARGCOUNT => 3},
		'NENUFAAR_ANALYSIS' => {ARGCOUNT => 1},
		'DBNSFP_V2' => {ARGCOUNT => 1},
		'DBNSFP_V3_PATH' => {ARGCOUNT => 1},
		'VARIANTVALIDATOR_GENOME' => {ARGCOUNT => 1},
		'VARIANTVALIDATOR_GENUINE_API' => {ARGCOUNT => 1},
		'VARIANTVALIDATOR_EMERGENCY_API' => {ARGCOUNT => 1},
		'SEAL_URL' => {ARGCOUNT => 1},
		'SEAL_IP' => {ARGCOUNT => 1},
		'SEAL_RS_IURC' => {ARGCOUNT => 1},
		'SEAL_USER' => {ARGCOUNT => 1},
		'SEAL_PASSWORD' => {ARGCOUNT => 1},
		'SEAL_VCF_PATH' => {ARGCOUNT => 1},
		'MD_API_KEY' => {ARGCOUNT => 1},
		'MD_BASE_URL' => {ARGCOUNT => 1},
		'MD_API_CREATE' => {ARGCOUNT => 1}
	);
}



1;
