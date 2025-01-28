package U2_modules::U2_subs_1;

use U2_modules::U2_init_1;
#use Apache::Reload;
#remove above line for production!!!
use File::Temp qw(tempdir);
use URI::Encode qw(uri_encode uri_decode);
use strict;
use warnings;
use SOAP::Lite;
use Data::Dumper;
use JSON;
use LWP::UserAgent;


#   This program is part of ushvam2, USHer VAriant Manager version 2
#    Copyright (C) 2012-2015  David Baux
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
#		general subroutines and variables


our @COUNTRY = ('Unknown','France','Afghanistan','Albania','Algeria','American Samoa','Andorra','Angola','Anguilla','Antarctica','Antigua and Barbuda','Argentina','Armenia','Aruba','Australia','Austria','Azerbaijan','Bahamas','Bahrain','Bangladesh','Barbados','Belarus','Belgium','Belize','Benin','Bermuda','Bhutan','Bolivia','Bosnia and Herzegovina','Botswana','Bouvet Island','Brazil','British Indian Ocean Territory','Brunei','Bulgaria','Burkina Faso','Burundi','Cambodia','Cameroon','Canada','Cape Verde','Cayman Islands','Central African Republic','Chad','Chile','China','Christmas Island','Cocos Islands','Colombia','Comoros','Congo','Cook Islands','Costa Rica','Cote d\' Ivoire','Croatia','Cuba','Cyprus','Czech Republic','Congo','Denmark','Djibouti','Dominica','Dominican Republic','East Timor','Ecuador','Egypt','El Salvador','England','Equatorial Guinea','Eritrea','Estonia','Ethiopia','Falkland Islands','Faroe Islands','Fiji Islands','Finland','French Guiana','French Polynesia','French Southern and Antarctic Lands','Gabon','Gambia','Georgia','Germany','Ghana','Gibraltar','Greece','Greenland','Grenada','Guadeloupe','Guam','Guatemala','Guinea','Guinea-Bissau','Guyana','Haiti','Heard Island and McDonald Islands','Honduras','Hong Kong SAR','Hungary','Iceland','India','Indonesia','Iran','Iraq','Ireland','Israel','Italy','Jamaica','Japan','Jordan','Kazakhstan','Kenya','Kiribati','Korea','Kuwait','Kyrgyzstan','Laos','Latvia','Lebanon','Lesotho','Liberia','Libya','Liechtenstein','Lithuania','Luxembourg','Macao SAR','Macedonia','Madagascar','Malawi','Malaysia','Maldives','Mali','Malta','Marshall Islands','Martinique','Mauritania','Mauritius','Mayotte','Mexico','Micronesia','Moldova','Monaco','Mongolia','Montserrat','Morocco','Mozambique','Myanmar','Namibia','Nauru','Nepal','Netherlands','Netherlands Antilles','New Caledonia','New Zealand','Nicaragua','Niger','Nigeria','Niue','Norfolk Island','North Korea','Northern Ireland','Northern Mariana Islands','Norway','Oman','Pakistan','Palau','Panama','Papua New Guinea','Paraguay','Peru','Philippines','Pitcairn Islands','Poland','Portugal','Puerto Rico','Qatar','Reunion','Romania','Russia','Rwanda','Samoa','San Marino','Saudi Arabia','Scotland','Senegal','Serbia and Montenegro','Seychelles','Sierra Leone','Singapore','Slovakia','Slovenia','Solomon Islands','Somalia','South Africa','South Georgia and the South Sandwich Islands','Spain','Sri Lanka','St. Helena','St. Kitts and Nevis','St. Lucia','St. Pierre and Miquelon','St. Vincent and the Grenadines','Sudan','Suriname','Svalbard and Jan Mayen','Swaziland','Sweden','Switzerland','Syria','Taiwan','Tajikistan','Tanzania','Thailand','Togo','Tokelau','Tonga','Trinidad and Tobago','Tunisia','Turkey','Turkmenistan','Turks and Caicos Islands','Tuvalu','Uganda','Ukraine','United Arab Emirates','United Kingdom','United States','United States Minor Outlying Islands','Uruguay','Uzbekistan','Vanuatu','Vatican City','Venezuela','Viet Nam','Virgin Islands','Virgin Islands','Wales','Wallis and Futuna','Yemen','Zambia','Zimbabwe');

#manage groups

our @USHER = ('MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'CIB2', 'USH2A', 'ADGRV1', 'WHRN', 'CLRN1', 'HARS', 'VEZT', 'CEP250', 'PEX1', 'PEX6', 'PEX26', 'ABHD12');
our @USH1 = ('', 'MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'CIB2');
our @USH2 = ('USH2A', 'ADGRV1', 'WHRN');
our @USH3 = ('CLRN1', 'HARS1');
our @CHM = ('CHM');
our @DFNB = ('ADCY1', 'CABP2', 'CATSPER2', 'CDC14A', 'CEACAM16', 'CIB2', 'CLDN9', 'CLDN14', 'CLIC5', 'CLRN2', 'COCH', 'COL11A2', 'ELMOD3', 'ESPN', 'EPS8', 'EPS8L2', 'ESRP1', 'ESRRB', 'FOXI1', 'GIPC3', 'GJB2', 'GJB3', 'GJB6', 'GPR156', 'GPSM2', 'GRXCR1', 'GRXCR2', 'HGF', 'ILDR1', 'KARS1', 'KCNJ10', 'LHFPL5', 'LOXHD1', 'LRTOMT', 'MARVELD2', 'MITF', 'MPZL2', 'MSRB3', 'MYO3A', 'MYO6', 'MYO15A', 'OTOA', 'OTOF', 'OTOG', 'OTOGL', 'PEX13', 'PDZD7', 'PJVK', 'PTPRQ', 'RDX', 'RIPOR2', 'ROR1', 'S1PR2', 'SERPINB6', 'SLC26A4', 'SLC26A5', 'SLITRK6', 'SPNS2', 'STRC', 'SYNE4', 'TBC1D24', 'TECTA', 'TMC1', 'TMEM132E', 'TMIE', 'TMPRSS3', 'TPRN', 'TRIOBP', 'TSPEAR', 'WBP2');
our @DFNA = ('ABCC1', 'ACTG1', 'ATP2B2', 'CCDC50', 'CD164', 'CEACAM16', 'COCH', 'COL11A2', 'CRYM', 'DIABLO', 'DIAPH1', 'DIAPH3', 'DMXL2', 'DSPP', 'EYA1', 'EYA4', 'GJB2', 'GJB6', 'GJB3', 'GRHL2', 'GSDME', 'HOMER2', 'KCNQ4', 'KITLG', 'LMX1A', 'MIR96', 'MIR182', 'MIR183', 'MYH9', 'MYH14', 'MYL9', 'MYO1A', 'MYO3A', 'MYO6', 'NLRP3', 'OSBPL2', 'P2RX2', 'PLS1', 'PTPN11', 'PTPRQ', 'POU4F3', 'RIPOR2', 'SIX1', 'SLC12A2', 'SLC17A8', 'TBC1D24', 'TECTA', 'TJP2', 'TMC1', 'TNC', 'WFS1','RNR1', 'TOP2B', 'TRNL1', 'TRNS1', 'VANGL2');
our @NSRP = ('ABCA4', 'AIPL1', 'BBS1', 'BEST1', 'CDHR1', 'CERKL', 'CFAP418', 'CLRN1', 'CNGA1', 'CNGB1', 'CRB1', 'CTSD', 'DHDDS', 'EYS', 'FAM161A', 'FLVCR1', 'IDH3B', 'IMPG2', 'MAK', 'MERTK', 'NBAS', 'NR2E3', 'NRL', 'PDE6A', 'PDE6B', 'PDE6G', 'PRCD', 'PROM1', 'PRPF31', 'PRPH2', 'RP1', 'RP2', 'RBP3', 'RGR', 'RHO', 'RLBP1', 'RPE65', 'RPGR', 'PCARE', 'SAG', 'SNRNP200', 'TTC8', 'USH2A', 'WDR35', 'ZNF513');
our @DFNX = ('AIFM1', 'POU3F4', 'PRPS1', 'SMPX', 'COL4A6');
our @LCA = ('LRAT', 'SPATA7', 'TULP1', 'RPE65');
our @CEVA = ('CEVA');
#our @MITO = ('RNR1', 'TRNL1', 'TRNS1');
our @OTHER_NS = ('ACOX1', 'ACTB', 'ACY1', 'ALMS1', 'ATP6V0A4', 'ATP6V1B1', 'BSND', 'C1QTNF5', 'CACNA1D', 'CATSPER2', 'CHD7', 'CISD2', 'COL11A1', 'COL2A1', 'COL4A1', 'COL4A3', 'COL4A4', 'COL4A5', 'COL9A1', 'COL9A2', 'COL9A3', 'COLEC11', 'ECE1', 'EDN3', 'EDNRA', 'EDNRB', 'ERCC2', 'EYA1', 'FGF3', 'FGFR3', 'GATA3', 'HARS2', 'HSD17B4', 'JAG1', 'KARS1', 'KCNE1', 'KCNQ1', 'KIT', 'LARS2', 'MASP1', 'MITF', 'MTAP', 'MYO1F', 'NDP', 'NF2', 'OPA1', 'PAX1', 'PAX3', 'PAX6', 'PEX1', 'PEX6', 'PHYH', 'PLS1', 'PMP22', 'POLR1C', 'POLR1D', 'RBP4', 'SEMA3E', 'SIX1', 'SIX5', 'SLC4A11', 'SNAI2', 'SOX10', 'SOX2', 'TCOF1', 'TFAP2A', 'TIMM8A', 'TMEM231', 'TNC', 'TSHZ1', 'TWNK');
our @DAV = ('SIX1', 'KMT2D', 'KDM6A', 'ATP6V1B1', 'SLC26A4', 'FOXI1', 'KCNJ10', 'ATP6V0A4');
our @DSD = ('AKR1C2','AKR1C4','AMH','AMHR2','AR','ARL6','ARX','ATF3','ATRX','CBX2','CHD7','CITED2','CYB5A','CYP11A1','CYP17A1','DHH','DMRT1','DMRT2','FGF8','FGF9','FGFR1','FGFR2','FSHB','FSHR','GATA4','HOXA13','HSD17B3','HSD3B2','INSL3','ANOS1','LHB','LHCGR','MAMLD1','MAP3K1','MKKS','NR0B1','NR5A1','POR','RXFP2','SOX2','SOX3','SOX8','SOX9','SOX10','SRD5A2','SRY','STAR','TSPYL1','WDR11','WNT4','WT1','ZFPM2');
our @NM = ('ABHD5','ACAD9','ACADVL','ACTA1','ADSSL1','AGL','AGRN','ALG13','ALG14','ALG2','AMPD1','ANO5','ATP2A1','B3GALNT2','BAG3','BIN1','BVES','CACNA1A','CACNA1S','CAPN3','CASQ1','CAV3','CCDC78','CFL2','CHAT','CHKB','CHRNA1','CHRNB1','CHRND','CHRNE','CHRNG','CLCN1','CLN3','CNTN1','COL12A1','COL13A1','COL4A1','COL6A1','COL6A2','COL6A3','COLQ','CPT2','CRYAB','DAG1','DES','DMD','DNAJB6','DNM2','DOK7','DOLK','DPAGT1','DPM1','DPM2','DPM3','DYSF','EMD','ENO3','ETFA','ETFB','ETFDH','FHL1','FKRP','FKTN','FLAD1','FLNC','GAA','GBE1','GFPT1','GMPPB','GNE','GOLGA2','GYG1','GYS1','HNRNPA1','HNRNPDL','HSPG2','ISCU','ISPD','ITGA7','KBTBD13','KCNA1','KCNE3','KCNJ18','KCNJ2','KLHL40','KLHL41','KLHL9','KY','FOXL2','LAMA2','LAMB2','LAMP2','LDB3','LDHA','LIMS2','LMNA','LMOD3','LPIN1','LRP4','MATR3','MEGF10','MTM1','MUSK','MYBPC3','MYH2','MYH3','MYH7','MYH8','MYO18B','MYO9A','MYOT','NEB','NEK5','ORAI1','PABPN1','PFKM','PGAM2','PGK1','PGM1','PHKA1','PHKB','PIEZO2','PLEC','PNPLA2','PNPLA8','POMGNT1','POMGNT2','POMK','POMT1','POMT2','PREPL','PRKAG2','PYGM','PYROXD1','RAPSN','RBCK1','RYR1','SCN4A','SELENON','SGCA','SGCB','SGCD','SGCG','SLC22A5','SLC25A1','SLC25A20','SLC25A32','SLC35A1','SLC35A2','SLC5A7','SNAP25','SPEG','SQSTM1','STAC3','STIM1','SYT2','TCAP','TIA1','TMEM5','TNNT1','TNPO3','TOR1AIP1','TPM2','TPM3','TRAPPC11','TRIM32','TRIM54','TRIP4','TTN','VCP','VMA21');

our @DSD_RESEARCH = ('GPAT2','AIRE','ALMS1','ALX4','ARID1B','ATR','BBS10','BBS12','BBS2','BBS4','BBS5','BBS7','BBS9','BLM','BMP15','BMP4','BMPR1B','BRCC3','BRWD3','BSCL2','CD96','CDKN1C','CEP290','CHRM3','CUL7','CYP19A1','CYP21A2','DCAF17','DDX3Y','DGKK','DHCR7','DIAPH2','DMRT3','DOCK8','EBP','EIF1AY','EIF2B1','EIF2B2','EIF2B3','EIF2B4','EIF2B5','ERCC8','EVC','EVC2','FGD1','FIGLA','FLNA','FOXL2','GATA1','GHR','GK','GNRH1','GNRHR','GLI3','GNAS','GPC6','H6PD','HARS2','HCCS','HDAC8','HESX1','HOXD13','HPRT1','HS6ST1','HSD11B1','HSD17B4','ICK','IGSF1','INPP5E','INSR','IRF6','IRX5','KDM5C','KDM5D','KIF7','KISS1','KISS1R','KLHL4','LEP','LEPR','LHX3','LMNA','MAP2K1','MBTPS2','MECP2','MED12','MID1','MKS1','MTCP1','MTM1','NAA10','NBN','NOBOX','NOTCH2','NR3C1','NRP1','NSDHL','NSMF','OCRL','OFD1','OPHN1','ORC1','PAPSS2','PAX2','PCDH11Y','PCSK1','PEX1','PEX12','PEX14','PEX2','PEX26','PEX3','PEX5','PEX6','PHF6','PITX2','PMM2','POF1B','POLG','POLR3A','PRKAR1A','PROP1','PROK2','PROKR2','PSMC3IP','PTPN11','RAB23','RAB3GAP2','RAB40AL','RAF1','RECQL4','RSPO1','SF3B4','SLC29A3','SLC39A4','SMS','SOS1','TAC3','TACR3','TMEM67','TRIM32','TTC8','UBR1','USP26','USP9Y','WT1','WWOX','BBS1','BMP2','BUB1B','CREBBP','CTNNB1','CUL4B','CYP11B1','EMX2','FRAS1','FREM2','KRT19','RIPK4','ROR2','SEMA3A','SEMA3E','SMARCA2','STK11','STRA6','TBCE','TBX3','TP63','UPK3A','WDPCP');

our @ND = ('AAAS','AARS','AARS2','ABCB7','ABCD1','ABHD12','ABHD5','ACO2','ACOX1','ACTB','ADA2','ADAR','ADCY5','ADGRG1','AFG3L2','AHI1','AIMP1','ALAS2','ALDH18A1','ALDH3A2','ALDH5A1','ALDH7A1','ALG6','ALS2','AMACR','AMPD2','ANO10','AP4B1','AP4E1','AP4M1','AP4S1','AP5Z1','APOB','APTX','ARL13B','ARSA','ARSI','ARV1','ARX','ASPA','ATCAY','ATG5','ATG7','ATL1','ATM','ATP13A2','ATP1A2','ATP1A3','ATP6AP2','ATP7B','ATP8A2','AUH','B4GALNT1','BCAP31','BCKDHB','BRAT1','BRF1','BSCL2','BTD','C12orf65','C19orf12','CA8','CACNA1A','CACNA1G','CAPN1','CASK','CC2D2A','CCDC88C','CCT5','CD59','CDKL5','CEP104','CEP290','CEP41','CHMP1A','CISD2','CLCN2','CLN3','CLN5','CLN6','CLP1','CLPP','CNTN2','COASY','COG5','COL18A1','COL4A1','COL6A3','COMT','COQ2','COQ4','COQ8A','COQ9','COX15','COX20','CP','CSF1R','CSPP1','CSTB','CTC1','CTDP1','CTSA','CTSD','CWF19L1','CYP27A1','CYP2U1','CYP7B1','DARS2','DCAF17','DCTN1','DDB2','DDC','DDHD1','DDHD2','DHFR','DKC1','DLAT','DLD','DMXL2','DNAJC19','DNAJC3','DNAJC5','DNAJC6','DNM1L','DRD5','EARS2','EGR2','EIF2B1','EIF2B2','EIF2B3','EIF2B4','EIF2B5','ELOVL4','ELOVL5','EMC1','ENTPD1','EPM2A','ERCC2','ERCC3','ERCC4','ERCC5','ERCC6','ERCC8','ERLIN1','ERLIN2','ETFA','ETFB','ETFDH','ETHE1','EXOSC3','EXOSC8','FA2H','FAM126A','FARS2','FBXL4','FBXO7','FGF14','FKRP','FKTN','FLVCR1','FOLR1','FOXG1','FOXRED1','FRMD4A','FTL','FUCA1','GAD1','GALC','GAMT','GARS','GBA','GBA2','GBE1','GCDH','GCH1','GCLC','GFAP','GIGYF2','GJA1','GJC2','GLB1','GLDC','GLRA1','GLRB','GM2A','GMPPA','GMPPB','GOSR2','GRID2','GRIN2B','GRM1','GRN','HACE1','HARS','HARS2','HEPACAM','HERC1','HEXA','HEXB','HIBCH','HMGCL','HPD','HPRT1','HSD17B4','HSPD1','HTRA1','HTRA2','IFIH1','IFT140','INPP5E','ITPR1','KARS1','KCNA1','KCNC3','KCND3','KCNJ10','KCNMA1','KCTD7','KIF1A','KIF1C','KIF5A','KIF7','L1CAM','L2HGDH','LAMA1','LAMA2','LAMB1','LARGE1','LARS2','LMNB1','LMNB2','LRRK2','LYST','MAG','MAN2B1','MARS2','MCOLN1','MECP2','MFN2','MFSD8','MICU1','MKS1','MLC1','MMACHC','MMADHC','MPLKIP','MPV17','MPZ','MTFMT','MTO1','MTPAP','MTTP','MVK','NARS2','NDUFA1','NDUFA10','NDUFA12','NDUFA13','NDUFA2','NDUFA6','NDUFA9','NDUFAF2','NDUFS3','NDUFS4','NDUFS7','NDUFS8','NDUFV1','NEFL','NHLRC1','NIPA1','NKX2','NPC1','NPC2','NPHP1','NR2F1','NUBPL','NUP62','OFD1','OPA1','OPA3','OPHN1','OTC','PANK2','PARN','PAX6','PCLO','PCNA','PDE6D','PDGFB','PDHA1','PDHX','PDSS1','PDSS2','PDYN','PEX1','PEX10','PEX11B','PEX12','PEX13','PEX14','PEX16','PEX19','PEX2','PEX26','PEX3','PEX5','PEX6','PEX7','PGAP1','PGM3','PHYH','PIGG','PINK1','PITRM1','PLA2G6','PLP1','PMM2','PMP22','PMPCA','PNKD','PNKP','PNP','PNPLA6','POLG','POLH','POLR1C','POLR1D','POLR2E','POLR3A','POLR3B','POMGNT1','POMT1','POMT2','PRDM8','PRF1','PRICKLE1','PRKCG','PRKN','PRKRA','PRNP','PRPS1','PRRT2','PRX','PSAP','PTF1A','PTRH2','PYCR2','QDPR','RAB29','RAB39B','RAB3GAP1','RAB3GAP2','RARS2','REEP1','RELN','RNASEH1','RNASEH2A','RNASEH2B','RNASEH2C','RNASET2','RNF170','RNF216','ROGDI','RORA','RP1L1','RPGRIP1L','RPIA','RRM2B','RTN2','RTN4IP1','RUBCN','SACS','SAMHD1','SAR1B','SARS2','SCARB2','SCN1A','SCP2','SCYL1','SDHA','SDHAF1','SEPSECS','SETX','SGCE','SHANK3','SIL1','SLC13A5','SLC16A2','SLC17A5','SLC19A3','SLC1A3','SLC25A15','SLC25A20','SLC25A46','SLC2A1','SLC30A10','SLC30A9','SLC33A1','SLC39A8','SLC46A1','SLC52A2','SLC52A3','SLC6A19','SLC6A3','SLC9A1','SLC9A6','SMN1','SNCA','SNX14','SOD1','SOX10','SOX2','SPART','SPAST','SPG11','SPG21','SPG7','SPR','SPTAN1','SPTBN2','SRD5A3','STIL','STUB1','SUCLA2','SUMF1','SUOX','SURF1','SYNE1','SYNJ1','SYT14','TAF1','TAZ','TBC1D24','TCTN1','TCTN2','TCTN3','TDP1','TDP2','TECPR2','TELO2','TH','THAP1','THG1L','TIMM8A','TMEM126A','TMEM138','TMEM216','TMEM231','TMEM237','TMEM240','TMEM67','TOR1A','TPK1','TPP1','TRAPPC11','TREM2','TREX1','TRNT1','TSEN2','TSEN34','TSEN54','TSFM','TTBK2','TTC19','TTPA','TUBA8','TUBB4A','TWNK','TXN2','TYMP','TYROBP','UBA5','UCHL1','UROC1','VCP','VLDLR','VPS13A','VPS13B','VPS35','VPS53','VRK1','VWA3B','WASHC5','WDR45','WDR62','WDR73','WDR81','WFS1','WWOX','XK','XPA','XPC','XRCC1','XRCC4','YARS','YARS2','ZFYVE26','ZNF423');

#our @NOGROUP = ();


# values for quality criteria (NGS) panel
# number of on target reads mini
# = (panel size in kb * enrichment coeff * mean expected doc) / read size
# = (900000 * 1,3 * 150) / 150 = 1170000
# 152 genes
# = (993000 *1,3 * 150) / 150 = 1290900
our $NUM_ONTARGET_READS = 1170000;
our $NUM_ONTARGET_READS_152 = 1290900;
our $NUM_ONTARGET_READS_158 = 1434612;
our $NUM_ONTARGET_READS_149 = 1342425;
our $TITV = 2.1;
our $MDOC = 150;
our $PC50X = 95;
our $Q30 = 80;
# for whole genes
our $TITV_WG = 1.8;
our $PC50X_WG = 70;
# Clinical exomes
our $PC20X_CE = 75;
our $MDOC_CE = 30;
our $TITV_CE = 2.8;
# Values to estimate contamination - NS149
our $NB_HOMOZYGOUS_VARS_149 = 300;
our $MEAN_AB_149 = 0.58;
# Values to estimate contamination - NS157
our $NB_HOMOZYGOUS_VARS_157 = 400;
our $MEAN_AB_157 = 0.58;

#threshold values for POMPS
our $SIFT_THRESHOLD = 0.05;
our $PPH2_THRESHOLD = 0.447;
our $FATHMM_THRESHOLD = -1.5;
our $METALR_THRESHOLD = 0.5;
our $MCAP_THRESHOLD = 0.025;
our $SPLICEAI_THRESHOLD_MIN = 0.2;
our $SPLICEAI_THRESHOLD_MED = 0.4;
our $SPLICEAI_THRESHOLD_MAX = 0.8;

#regexp to capture chromosomes
our $CHR_REGEXP = '[\dXYM]{1,2}';
our $HGVS_CHR_TAG = '[gm]';
our $HGVS_TRANSCRIPT_TAG = '[cm]';

# SEAL correspondance hash between BED filters and ids
our $SEAL_BED_IDS = {
	'DFN' => 19,
	'DFN-USH' => 20,
	'CHM' => 21,
	'RP' => 22,
	'RP-USH' => 23,
	'USH' => 24
};

#genes for aCGH
our @ACGH = ('MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'CIB2', 'USH2A', 'ADGRV1', 'WRHN', 'CLRN1', 'PDZD7', 'CHM', 'OTOF', 'TECTA', 'MYO15A', 'COCH', 'TMC1', 'SLC26A4', 'KCNQ4', 'EYA4', 'TMPRSS3', 'WFS1', 'MYO6', 'EYS', 'GJB2', 'GJB6', 'POU3F4', 'ACTG1');
#genes for our LOVD install - deprecated 2014/12/17 in variant.pl- reused since
our @LOVD = ('MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'USH2A', 'ADGRV1', 'WHRN', 'CLRN1', 'CHM', 'MYO15A', 'OTOF', 'PDZD7', 'SLC26A4', 'TECTA',' TMC1', 'MYO6');


my $config_file = U2_modules::U2_init_1->getConfFile();
my $config = U2_modules::U2_init_1->initConfig();
$config->file($config_file);# or die $!;
my $HTDOCS_PATH = $config->HTDOCS_PATH();
# my $RS_BASE_DIR = $config->RS_BASE_DIR();
my $NAS_CHU_BASE_DIR = $config->NAS_CHU_BASE_DIR();
my $PATIENT_IDS = $config->PATIENT_IDS();
my $PATIENT_FAMILY_IDS = $config->PATIENT_FAMILY_IDS();
my $PATIENT_PHENOTYPE = $config->PATIENT_PHENOTYPE();
my $ANALYSIS_MISEQ_FILTER = $config->ANALYSIS_MISEQ_FILTER();
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $PYTHON = $config->PYTHON_PATH();
my $VARIANTVALIDATOR_GENUINE_API = $config->VARIANTVALIDATOR_GENUINE_API();
my $VARIANTVALIDATOR_EMERGENCY_API = $config->VARIANTVALIDATOR_EMERGENCY_API();


#hg38 transition variable for postgresql 'start_g' segment field
my ($postgre_start_g, $postgre_end_g) = ('start_g', 'end_g');  #hg19 style

# HTML subs

sub standard_begin_html { #prints top of the pages
	my ($q, $user_name, $dbh) = @_;
	#prints fix_top.html in one div and starts main div , 'src' => $HTDOCS_PATH.'fix_top.shtml'
	#print $q->start_div({'id' => 'page'}), $q->start_div({'id' => 'fixtop'}), $q->end_div(), $q->br(), $q->br(),
	#$q->start_div({'id' => 'internal'}), $q->p({'id' => 'log'}, 'logged in as '.$user_name), $q->br();
	#$q->start_a({'href' => '#bottom', 'class' => 'print_hidden'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/bottom_arrow.png', 'width' => '23', 'height' => '34', 'border' => '0'}), $q->strong('Go to bottom'), $q->end_a(), $q->br();
	print $q->start_div({'id' => 'page', 'class' => 'w3-medium'}), $q->start_div({'class' => 'w3-top', 'style' => 'z-index:1112'}),
		$q->start_div({'id' => 'scroll', 'class' => 'w3-white w3-opacity-min'}),
			$q->start_div({'id' => 'scroll-bar', 'class' => 'w3-blue', 'style' => 'height:4px;width:0%'}), $q->end_div(),
		$q->end_div(),
		$q->start_div({'id' => 'myNavbar', 'class' => 'w3-bar w3-card-2 w3-black'}),
		$q->start_div({'class' => 'w3-dropdown-hover'}),
			$q->start_a({'class' => 'w3-button w3-ripple w3-black', 'onclick' => 'window.location="/U2/";'}),$q->start_i({'class' => 'fa fa-home w3-xxlarge'}), $q->end_i(), $q->end_a(),
			$q->start_div({'class' => 'w3-dropdown-content w3-bar-block w3-card-4'}),
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/resources.pl'}, 'Resources'),
			$q->end_div(),
		$q->end_div(),
		$q->start_div({'class' => 'w3-dropdown-hover'}),
			$q->start_a({'class' => 'w3-button w3-ripple w3-black'}),$q->start_i({'class' => 'fa fa-stethoscope w3-xxlarge'}), $q->end_i(), $q->end_a(),
			#$q->a({'class' => 'w3-button w3-ripple w3-large'},'Patients'),
			$q->start_div({'class' => 'w3-dropdown-content w3-bar-block w3-card-4'});
	#get patients' pathologies
	my $query = "SELECT pathologie FROM valid_pathologie ORDER BY id;";
	print $q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/patients.pl?phenotype=all'}, 'ALL');
		#$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/patients.pl?phenotype=USHER'}, 'USHER');
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		print $q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => "/perl/U2/patients.pl?phenotype=$result->{'pathologie'}"}, $result->{'pathologie'});
	}
		#		$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-xlarge', 'href' => '/perl/U2/resources.pl'}, 'Resources'),
	print 		$q->end_div(),
		$q->end_div(),
		$q->start_div({'class' => 'w3-dropdown-hover'}), "\n",
			$q->start_a({'class' => 'w3-button w3-ripple w3-black'}),$q->start_i({'class' => 'fa fa-ioxhost w3-xxlarge'}), $q->end_i(), $q->end_a(), "\n",
			#$q->a({'class' => 'w3-button w3-ripple w3-xlarge'},'Genes'),
			$q->start_div({'class' => 'w3-dropdown-content w3-bar-block w3-card-4'}), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=ALL'}, 'ALL'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=USHER'}, 'USHER'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=DFNB'}, 'DFNB'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=DFNA'}, 'DFNA'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=DFNX'}, 'DFNX'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=NSRP'}, 'NSRP'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=CHM'}, 'CHM'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=LCA'}, 'LCA'), "\n",
			$q->end_div(), "\n",
		$q->end_div(), "\n",
		$q->start_div({'class' => 'w3-dropdown-hover'}), "\n",
			$q->start_a({'class' => 'w3-button w3-ripple w3-black'}),$q->start_i({'class' => 'fa fa-pie-chart w3-xxlarge'}), $q->end_i(), $q->end_a(), "\n",
			#$q->a({'class' => 'w3-button w3-ripple w3-large'},'Statistics'),
			$q->start_div({'class' => 'w3-dropdown-content w3-bar-block w3-card-4'}), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/stats_ngs.pl'}, 'Illumina tables'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/stats_ngs.pl?graph=1'}, 'Illumina graphs'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/ngs_compare.pl'}, 'NGS compare'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/stats_general_1.pl'}, 'General Stats'), "\n",
			$q->end_div(), "\n",
		$q->end_div(), "\n",
		$q->start_div({'class' => 'w3-dropdown-hover'}), "\n",
			#$q->a({'class' => 'w3-button w3-ripple w3-large'},'Advanced'),
			$q->start_a({'class' => 'w3-button w3-ripple w3-black'}),$q->start_i({'class' => 'fa fa-gears w3-xxlarge'}), $q->end_i(), $q->end_a(), "\n",
			$q->start_div({'class' => 'w3-dropdown-content w3-bar-block w3-card-4'}), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/automated_class.pl?class=1', 'onclick' => 'info(\'class\');'}, 'Automatic Classification'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/automated_class.pl?neg=1', 'onclick' => 'info(\'neg\');'}, 'Automatic Negative'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/search_controls.pl?step=1'}, 'Search Controls'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/advanced.pl?advanced=non-USH'}, 'USH non-USH'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/advanced.pl?advanced=forgotten_samples'}, 'Forgotten Samples'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/advanced.pl?advanced=last_creations'}, 'Last Samples'), "\n",
			$q->end_div(), "\n",
		$q->end_div(), "\n",
		$q->start_a({'class' => 'w3-bar-item w3-button w3-ripple w3-xlarge w3-right', 'href' => '/ushvam2/change_user.php'}), $q->start_i({'class' => 'fa fa-user-times w3-xxlarge'}), $q->end_i(), $q->end_a(),
		$q->span({'class' => 'w3-bar-item w3-xlarge w3-right'}, "Logged in as $user_name"), "\n",
		$q->end_div(), $q->end_div(), $q->br(), $q->br(), "\n",
		$q->start_div({'id' => 'internal'}), $q->br(), "\n";

}

sub public_begin_html { #prints top of the pages
	my ($q, $user_name, $dbh) = @_;
	print $q->start_div({'id' => 'page', 'class' => 'w3-medium'}), $q->start_div({'class' => 'w3-top', 'style' => 'z-index:1112'}),
		$q->start_div({'id' => 'scroll', 'class' => 'w3-white w3-opacity-min'}),
			$q->start_div({'id' => 'scroll-bar', 'class' => 'w3-blue', 'style' => 'height:4px;width:0%'}), $q->end_div(),
		$q->end_div(),
		$q->start_div({'id' => 'myNavbar', 'class' => 'w3-bar w3-card-2 w3-black'}),
		$q->start_div({'class' => 'w3-dropdown-hover'}),
			$q->start_a({'class' => 'w3-button w3-ripple w3-black', 'onclick' => 'window.location="/U2/";'}),$q->start_i({'class' => 'fa fa-home w3-xxlarge'}), $q->end_i(), $q->end_a(),
			$q->start_div({'class' => 'w3-dropdown-content w3-bar-block w3-card-4'}),
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/aboutMD.pl'}, 'About'),
			$q->end_div(),
		$q->end_div(),
		$q->start_div({'class' => 'w3-dropdown-hover'}), "\n",
			$q->start_a({'class' => 'w3-button w3-ripple w3-black'}),$q->start_i({'class' => 'fa fa-ioxhost w3-xxlarge'}), $q->end_i(), $q->end_a(), "\n",
			#$q->a({'class' => 'w3-button w3-ripple w3-xlarge'},'Genes'),
			$q->start_div({'class' => 'w3-dropdown-content w3-bar-block w3-card-4'}), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=ALL'}, 'ALL'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=DSD'}, 'DSD'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=DSDR'}, 'DSD Research'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=ND'}, 'ND'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=NM'}, 'NM'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=NS'}, 'NS'), "\n",
			$q->end_div(), "\n",
		$q->end_div(),
		$q->start_a({'class' => 'w3-bar-item w3-button w3-ripple w3-xlarge w3-right', 'href' => '/ushvam2/change_user.php'}), $q->start_i({'class' => 'fa fa-user-times w3-xxlarge'}), $q->end_i(), $q->end_a(),
		$q->span({'class' => 'w3-bar-item w3-xlarge w3-right'}, "Logged in as $user_name"), "\n",
		$q->end_div(), $q->end_div(), $q->br(), $q->br(), "\n",
		$q->start_div({'id' => 'internal'}), $q->br(), "\n";
}

sub standard_end_html { #prints bottom of the pages
	my ($q) = shift;
	#ends main div and prints fix_bot.html , 'src' => $HTDOCS_PATH.'fix_bot.html'
	#print $q->end_div(), $q->br(), $q->start_div({'id' => 'bottom', 'align' => 'right', 'class' => 'print_hidden'}), $q->start_a({'href' => '#page'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/top_arrow.png', 'width' => '23', 'height' => '34', 'border' => '0'}), $q->strong('Go to top'), $q->end_a(), $q->end_div(), "\n",
	print $q->end_div(), $q->br(), $q->start_div({'id' => 'fixbot', 'class' => 'w3-container w3-center fixbot'}), $q->end_div(), $q->br(), $q->br(), $q->br(), $q->br(), $q->br(), $q->end_div();
}

sub public_end_html { #prints bottom of the pages
	my ($q) = shift;
	print $q->end_div(), $q->br(), $q->start_div({'class' => 'w3-container w3-center fixbot'}),
	$q->script({'type' => "text/javascript"}, "
\$(document).ready(function() {
	\$('#engine').autocomplete({
		serviceUrl: '/perl/U2/autocomplete.pl',
		type: 'POST',
		dataType: 'json',
		orientation: 'top',
		onSelect: function(){\$(\"#search_form\").submit();},
		minChars: 2,
		preventBadQueries: false,
		showNoSuggestionNotice: true,
		noSuggestionNotice: 'No results in patient or gene names'
	});
	\$('#main_engine').autocomplete({
		serviceUrl: '/perl/U2/autocomplete.pl',
		type: 'POST',
		dataType: 'json',
		orientation: 'top',
		onSelect: function(){\$(\"#main\").submit();},
		minChars: 2,
		preventBadQueries: false,
		showNoSuggestionNotice: true,
		noSuggestionNotice: 'No results in patient or gene names'
	});
});"),
	$q->start_form({'action' => "/perl/U2/engine_public.pl", 'id' => "search_form"}),
		$q->start_div({'class' => "w3-row"}),
			$q->start_div({'class' => "w3-half w3-right-align"}),
				$q->input({'type' => "text", 'class' => "w3-input w3-border w3-large", 'name' => "search", 'id' => "engine", 'size' => "30", 'style' => "width:200px;display:inline;", 'maxlength' => "40", 'placeholder' => " Ask MobiDetails:", 'autofocus' => "autofocus"}),
			$q->end_div(),
			$q->start_div({'class' =>"w3-quarter"}), $q->input({'type' => "submit", 'id' => "submit_a", 'value' => "Submit", 'class' => "w3-button w3-white w3-large w3-border"}),
			$q->end_div(),
		$q->end_div(),
		$q->end_form(), "\n",
	$q->end_div(), $q->br(), $q->br(), $q->br(), $q->br(), $q->br(), $q->end_div();
}

#common header for gene pages in gene.pl, gene_graphs.pl
sub gene_header {
	my ($q, $current_tab, $gene, $user) = @_;

	print $q->start_div({'class' => 'w3-container'}), $q->start_h2(), $q->em($gene), $q->span(" page:"), $q->end_h2(), "\n",
		$q->br(), $q->start_div({'class' => 'w3-row'}), "\n";
	if ($current_tab eq 'general_info') {&print_span(' w3-border-red', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=general', '_self');", 'General features', $q)}
	else {&print_span('', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=general', '_self');", 'General info', $q)}
	if ($current_tab eq 'structure') {&print_span(' w3-border-red', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=structure', '_self');", 'Exon structure', $q)}
	else {&print_span('', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=structure', '_self');", 'Exons structure', $q)}
	if ($current_tab eq 'var_all') {&print_span(' w3-border-red', $current_tab, "chooseSortingType('$gene');", 'Get all variants', $q)}
	else {&print_span('', $current_tab, "chooseSortingType('$gene');", 'Get all variants', $q)}
	if ($user->isPublic() != 1) {
		if ($current_tab eq 'genotypes') {&print_span(' w3-border-red', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=genotype', '_self');", 'Genotypes', $q)}
		else {&print_span('', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=genotype', '_self');", 'Genotypes', $q)}
		if ($current_tab eq 'graphs') {&print_span(' w3-border-red', $current_tab, "window.open('gene_graphs.pl?gene=$gene', '_self');", 'Beautiful graphs', $q)}
		else {&print_span('', $current_tab, "window.open('gene_graphs.pl?gene=$gene', '_self');", 'Beautiful graphs', $q)}
	}

	#"chooseSortingType('$gene');"

	print $q->end_div(), $q->end_div(),"\n",
		$q->div({'class' => 'tab_content', 'style' => 'display:block;'}), "\n";

}
#used in gene_header
sub print_span {
	my ($class, $id, $action, $title, $q) = @_;
	print "\t", $q->span({'class' => "tablink w3-bottombar w3-hover-light-grey w3-padding pointer".$class, 'id' => $id, 'onclick' => $action}, $title), "\n";
}
sub accent2html {
	my ($str) = shift;
	#ok
	$str =~ s/�/&eacute;/og;
	$str =~ s/�/&aacute;/og;
	$str =~ s/�/&uacute;/og;
	$str =~ s/�/&iacute;/og;
	$str =~ s/�/&oacute;/og;
	$str =~ s/�/&egrave;/og;
	$str =~ s/�/&ugrave;/og;
	$str =~ s/�/&ograve;/og;
	$str =~ s/�/&agrave;/og;
	$str =~ s/�/&igrave;/og;
	$str =~ s/�/&Egrave;/og;
	$str =~ s/�/&Ugrave;/og;
	$str =~ s/�/&Ograve;/og;
	$str =~ s/�/&Agrave;/og;
	$str =~ s/�/&Igrave;/og;
	$str =~ s/�/&ccedil;/og;
	$str =~ s/�/&auml;/og;
	$str =~ s/�/&euml;/og;
	$str =~ s/�/&uuml;/og;
	$str =~ s/�/&iuml;/og;
	$str =~ s/�/&ouml;/og;
	$str =~ s/�/&Auml;/og;
	$str =~ s/�/&Euml;/og;
	$str =~ s/�/&Uuml;/og;
	$str =~ s/�/&Iuml;/og;
	$str =~ s/�/&Ouml;/og;
	$str =~ s/�/&ecirc;/og;
	$str =~ s/�/&ocirc;/og;
	$str =~ s/�/&acirc;/og;
	$str =~ s/�/&icirc;/og;
	$str =~ s/�/&ucirc;/og;
	$str =~ s/�/&Ecirc;/og;
	$str =~ s/�/&Ocirc;/og;
	$str =~ s/�/&Acirc;/og;
	$str =~ s/�/&Icirc;/og;
	$str =~ s/�/&Ucirc;/og;
	$str =~ s/�/O/og;
	$str =~ s/'/\'/og;
	return $str;
}
sub html2accent {
	my ($str) = shift;
	#ok
	$str =~ s/&eacute;/�/og;
	$str =~ s/&aacute;/�/og;
	$str =~ s/&uacute;/�/og;
	$str =~ s/&iacute;/�/og;
	$str =~ s/&oacute;/�/og;
	$str =~ s/&egrave;/�/og;
	$str =~ s/&ugrave;/�/og;
	$str =~ s/&ograve;/�/og;
	$str =~ s/&agrave;/�/og;
	$str =~ s/&igrave;/�/og;
	$str =~ s/&Egrave;/�/og;
	$str =~ s/&Ugrave;/�/og;
	$str =~ s/&Ograve;/�/og;
	$str =~ s/&Agrave;/�/og;
	$str =~ s/&Igrave;/�/og;
	$str =~ s/&ccedil;/�/og;
	$str =~ s/&auml;/�/og;
	$str =~ s/&euml;/�/og;
	$str =~ s/&uuml;/�/og;
	$str =~ s/&iuml;/�/og;
	$str =~ s/&ouml;/�/og;
	$str =~ s/&Auml;/�/og;
	$str =~ s/&Euml;/�/og;
	$str =~ s/&Uuml;/�/og;
	$str =~ s/&Iuml;/�/og;
	$str =~ s/&Ouml;/�/og;
	$str =~ s/&ecirc;/�/og;
	$str =~ s/&ocirc;/�/og;
	$str =~ s/&acirc;/�/og;
	$str =~ s/&icirc;/�/og;
	$str =~ s/&ucirc;/�/og;
	$str =~ s/&Ecirc;/�/og;
	$str =~ s/&Ocirc;/�/og;
	$str =~ s/&Acirc;/�/og;
	$str =~ s/&Icirc;/�/og;
	$str =~ s/&Ucirc;/�/og;
	$str =~ s/O/�/og;
	$str =~ s/\'/'/og;
	return $str;
}
# Form subs
sub select_origin { #insert a list of countries in a pop up menu
	my ($q) = shift;
	print $q->popup_menu(-name => 'origin', -id => 'origin', -values => \@COUNTRY, -class => 'w3-select w3-border');
}

sub select_phenotype { #insert a list of phenotypes in a pop up menu
	my ($q) = shift;
	$PATIENT_PHENOTYPE =~ /^\((.+)\)$/o;
	my @phenotype_tab = split(/\|/, $1);
	unshift @phenotype_tab, '';
	print $q->popup_menu(-name => 'phenotype', -id => 'phenotype', -values => \@phenotype_tab, -class => 'w3-select w3-border');
}

sub select_gene { #insert a list of genes in a pop up menu
	my ($q, $dbh) = @_;
	my @gene_list;
	my $sth = $dbh->prepare("SELECT gene_symbol as gene FROM gene;");
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {push @gene_list, $result->{'gene'}}
	print $q->popup_menu(-name => 'gene', -id => 'genes', -values => \@gene_list, -class => 'w3-select w3-border');
}

sub select_genes_grouped { #insert a list of genes in a pop up menu - group by phenotypes
	my ($q, $id, $form) = @_;
	print $q->popup_menu(-name => 'gene', -id => $id, -form => $form, -class => 'w3-select w3-border',
				-values => [
					$q->optgroup (-name => 'USHER', -values => \@USHER),
					# $q->optgroup (-name => 'USH2', -values => \@USH2),
					# $q->optgroup (-name => 'USH3', -values => \@USH3),
					$q->optgroup (-name => 'CHM', -values => \@CHM),
					$q->optgroup (-name => 'CEVA', -values => \@CEVA),
					$q->optgroup (-name => 'DFNB', -values => \@DFNB),
					$q->optgroup (-name => 'DFNA', -values => \@DFNA),
					$q->optgroup (-name => 'DFNX', -values => \@DFNX),
					$q->optgroup (-name => 'NSRP', -values => \@NSRP),
					$q->optgroup (-name => 'LCA', -values => \@LCA),
					$q->optgroup (-name => 'OTHER NS', -values => \@OTHER_NS),
					$q->optgroup (-name => 'DAV', -values => \@DAV),
					$q->optgroup (-name => 'ALL', -values => 'all', -hidden => 'hidden;')
					#$q->optgroup (-name => 'NO GROUP', -values => \@NOGROUP)
					    ]);
}
#in add_analysis.pl and patient_file.pl
sub select_filter { #insert a list of filter types in a pop up menu
	my ($q, $id, $form, $default) = @_;
	$ANALYSIS_MISEQ_FILTER =~ /^\((.+)\)$/o;
	my @filters = split(/\|/, $1);
	#my @filters = ('All', 'DFN', 'RP');
	if(!$default) {return $q->popup_menu(-name => $id, -id => $id, -form => $form, -values => \@filters, -class => 'w3-select w3-border')}
	else {return $q->popup_menu(-name => $id, -id => $id, -form => $form, -values => \@filters, -default => $default, -class => 'w3-select w3-border')}
}
#in add_analysis.pl
sub select_analysis {
	my ($q, $dbh, $form) = @_;
	my (@analysis_list, %analysis_labels);
	my $sth = $dbh->prepare("SELECT type_analyse, manifest_name FROM valid_type_analyse WHERE form = 't';");
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		push @analysis_list, $result->{'type_analyse'};
		if ($result->{'manifest_name'} ne 'no_manifest') {
			my $genome_version = U2_modules::U2_subs_1::get_genome_from_analysis( $result->{'type_analyse'}, $dbh) eq 'hg38' ? 'hg38' : 'hg19' ;
			$analysis_labels{$result->{'type_analyse'}} = "$result->{'type_analyse'} - $genome_version";
		}
		else {
			$analysis_labels{$result->{'type_analyse'}} = "$result->{'type_analyse'}";
		}
	}
	@analysis_list = sort(@analysis_list);
	# print STDERR Dumper(%analysis_labels);
	return $q->popup_menu(-name => 'analysis', -id => 'analysis', -form => $form, -values => \@analysis_list, -labels => \%analysis_labels, -onchange => 'associate_gene();', -class => 'w3-select w3-border');
}

sub valid {
	my ($user, $number, $id, $dbh, $q) = @_;
	if ($user->isAnalyst() == 1) {
		my $tech_val = "SELECT DISTINCT(c.gene_symbol), a.type_analyse FROM analyse_moleculaire a, valid_type_analyse b, gene c WHERE a.type_analyse = b.type_analyse AND a.refseq = b.refseq AND b.multiple = 'f' AND a.num_pat = '$number' AND a.id_pat = '$id' AND (a.technical_valid = 'f' OR a.result IS NULL OR a.valide = 'f');";
		my $sth = $dbh->prepare($tech_val);
		my $res = $sth->execute();
		my $html;
		if ($res ne '0E0') {
			while (my $result = $sth->fetchrow_hashref()) {
				$html .= $q->start_li().$q->em($result->{'gene_symbol'}).$q->span("&nbsp;&nbsp;($result->{'type_analyse'})&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;");
				$html .= $q->button({'value' => 'Access', 'onclick' => "document.location = 'add_analysis.pl?step=2&sample=$id$number&gene=$result->{'gene_symbol'}&analysis=$result->{'type_analyse'}';", 'class' => 'w3-button w3-ripple w3-blue'});
				$html .= $q->end_li();
			}
		}
		else {$html = $q->li('no analyses pending')}
		return $html;
	}
}

sub valid_table {
	my ($user, $number, $id, $dbh, $q) = @_;
	if ($user->isAnalyst() == 1) {
		my $tech_val = "SELECT DISTINCT(c.gene_symbol), a.type_analyse FROM analyse_moleculaire a, valid_type_analyse b, gene c WHERE a.type_analyse = b.type_analyse AND a.refseq = c.refseq AND b.multiple = 'f' AND a.type_analyse NOT LIKE '%xome' AND a.num_pat = '$number' AND a.id_pat = '$id' AND (a.technical_valid = 'f' OR a.result IS NULL OR a.valide = 'f');";
		my $sth = $dbh->prepare($tech_val);
		my $res = $sth->execute();
		my $html;
		if ($res ne '0E0') {
			$html .= $q->start_table({'class' => 'great_table technical'}).$q->start_Tr().$q->th({'class' => 'left_general'}, 'Gene').$q->th({'class' => 'left_general'}, 'Analysis').$q->end_Tr();#$q->th({'class' => 'left_general'}, 'Link').
			while (my $result = $sth->fetchrow_hashref()) {
				$html .= $q->start_Tr().$q->td({'class' => 'italique'}, $result->{'gene_symbol'});#.$q->td($result->{'type_analyse'});
				$html .= $q->start_td().$q->button({'value' => $result->{'type_analyse'}, 'onclick' => "document.location = 'add_analysis.pl?step=2&sample=$id$number&gene=$result->{'gene_symbol'}&analysis=$result->{'type_analyse'}';", 'class' => 'w3-button w3-ripple w3-blue'}).$q->end_td();
				$html .= $q->end_Tr();
			}
			$html .= $q->end_table();
		}
		else {$html = $q->span('no analyses pending')}
		return $html;
	}
}
# CGI params subs

sub check_step {  #check step cgi param : must be a number
	my ($q) = shift;
	if ($q->param('step') =~ /^(\d)$/o) {return $1}
	else {&standard_error('1', $q)}
}

sub check_phenotype { # check phenotype param
	my ($q) = shift;
	if ($q->param('phenotype') =~ /$PATIENT_PHENOTYPE/og) {return $1}
	else {&standard_error('3', $q)}
}
# in ajax.pl
sub check_family_id {
	my ($q) = shift;
	if ($q->param('family_id') =~ /$PATIENT_FAMILY_IDS(\d+)/og) {return $1.$2}
	else {&standard_error('27', $q)}
}
# used in ajax.pl
sub check_proband {
	my ($q) = shift;
	if ($q->param('proband') =~ /(yes|no)/og) {return $1}
	else {&standard_error('29', $q)}
}
#used in import_illumina.pl, add_analysis.pl
sub sample2idnum { #transform a sample into an id and a number
	my ($sample, $q) = @_;
	if ($sample =~ /^$PATIENT_IDS\s*(\d+)$/o) {return($1, $2)}
	else {&standard_error('2', $q)}
}

sub check_gene { #checks gene param
	my ($q, $dbh) = @_;
	# print STDERR "gene param:".$q->param('gene')."\n";
	if ($q->param('gene') eq 'all') {return ('all', 'all')}
	elsif ($q->param('gene') =~ /([\w-]+)/og) {
		my $name = $1;
		if ($name =~ /ORF/o) {$name =~ s/ORF/orf/og}
		my $query = "SELECT DISTINCT (gene_symbol) as gene, second_name FROM gene WHERE gene_symbol = '$name';";
		my $res = $dbh->selectrow_hashref($query);
		if ($res->{'gene'} ne '0E0') {return ($res->{'gene'}, $res->{'second_name'})}
		else {&standard_error('5', $q)}
	}
	else {&standard_error('4', $q)}
}

sub check_genome {
	my ($q) = shift;
	if ($q->param('genome') =~ /(hg[13][98])/o) {
		return $1;
	}
}

sub create_image_file_name {
	my ($gene, $ng) = @_;
	if ($ng =~ /g\.(\d+).*(_\d+).*(del|dup|ins).*/o) {
		return ($gene."_".$1.$2.$3.".png", $1, $2, $3);
	}
}

sub check_acc {
	#checks gene param
	my ($q, $dbh) = @_;
	if ($q->param('accession') =~ /(N[MRGC]_\d+\.*\d*)/og) {
		# in variant_input_vv.pl step 3 fake NM
		if ($1 eq 'NM_000001.1') {return $1}
		my $query = "SELECT refseq as acc FROM gene WHERE refseq = '$1';";
		if ($1 =~ /NG_.+/o) {$query = "SELECT acc_g as acc FROM gene WHERE refseq = '$1';";}
		my $res = $dbh->selectrow_hashref($query);
		if ($res->{'acc'} && $res->{'acc'} ne '0E0') {return $res->{'acc'}}
		else {&standard_error('6', $q)}
	}
	else {&standard_error('7', $q)}
}

sub check_nom_c {
	my ($q, $dbh) = @_;
	if (uri_decode($q->param('nom_c')) =~ /([nc]\.[>\w\*\-\+\?_\{\}]+)/og) {
		my $query = "SELECT a.nom as var FROM variant a, gene b WHERE a.refseq = b.refseq AND a.nom = '$1' AND b.gene_symbol = '".$q->param('gene')."';";
		#print $query;
		my $res = $dbh->selectrow_hashref($query);
		if ($res->{'var'} ne '0E0') {return $res->{'var'}}
		else {&standard_error('9', $q)}
	}
	else {&standard_error('8', $q)}
}
#get nom_gene in splicing_calc.pl, otherwise get var
sub check_nom_g {
	my ($q, $dbh) = @_;
	#if (uri_decode($q->param('nom_g')) =~ /(chr[\dXY]+:g\.[>\w\*\-\+\?_\{\}]+)/og) {
	if (uri_decode($q->param('nom_g')) =~ /(chr$CHR_REGEXP:$HGVS_CHR_TAG\.[>\w\*\-\+\?_\{\}]+)/og) {
		my $query = "SELECT nom_g as var FROM variant WHERE nom_g = '$1';";
		#print $query;
		my $res = $dbh->selectrow_hashref($query);
		if ($res->{'var'} ne '0E0') {return ($res->{'var'})}
		else {&standard_error('9', $q)}
	}
	else {&standard_error('8', $q)}
}
#in ajax.pl get ref and alt aa for missense
sub decompose_nom_p {
	my $prot = shift;
	if ($prot =~ /p.\(?([A-Z][a-z]{2})\d+([A-Z][a-z]{2})\)?/o) {
		return (three2one($1), three2one($2));
	}
}


#in ajax.pl,gets enst or ensp as type
sub check_ens {
	my ($q, $dbh, $type) = @_;
	if (uri_decode($q->param($type)) =~ /(ENST\d+)/og) {
		my $query = "SELECT $type FROM gene WHERE $type = '$1';";
		#print $query;
		my $res = $dbh->selectrow_hashref($query);
		if ($res->{$type} ne '0E0') {return $res->{$type}}
		else {&standard_error('6', $q)}
	}
	else {&standard_error('7', $q)}
}

sub check_status {
	my ($q) = shift;
	if ($q->param('status') =~ /(homozygous|heterozygous|hemizygous|homoplasmic|heteroplasmic)/o) {return $1}
	else {&standard_error('16', $q)}
}
sub check_allele {
	my ($q) = shift;
	if ($q->param('allele') =~ /(1|2|both|unknown)/o) {return $1}
	else {&standard_error('16', $q)}
}
sub check_denovo {
	my ($q) = shift;
	if ($q->param('denovo') =~ /(true)/o) {return $1}
	else {return 'false'}
}
sub check_status_modify {
	my ($q) = shift;
	if ($q->param('status_modify') =~ /(homozygous|heterozygous|hemizygous|homoplasmic|heteroplasmic)/o) {return $1}
	else {&standard_error('16', $q)}
}
sub check_allele_modify {
	my ($q) = shift;
	if ($q->param('allele_modify') =~ /(1|2|both|unknown)/o) {return $1}
	else {&standard_error('16', $q)}
}
sub check_denovo_modify {
	my ($q) = shift;
	if ($q->param('denovo_modify') =~ /(true)/o) {return $1}
	else {return 'false'}
}
#used in add_analysis.pl, ajax.pl
sub check_analysis {
	my ($q, $dbh, $mode) = @_;
	if ($q->param('analysis') && $q->param('analysis') =~ /^([\w\(\)-]+)$/og) {
		my $totest = $1;
		my $res = $dbh->selectrow_hashref("SELECT type_analyse FROM valid_type_analyse WHERE type_analyse = '$totest' AND form = 't';");
		if ($mode eq 'basic') {$res = $dbh->selectrow_hashref("SELECT type_analyse FROM valid_type_analyse WHERE type_analyse = '$totest';")}
		if ($mode eq 'filtering') {$res = $dbh->selectrow_hashref("SELECT type_analyse FROM valid_type_analyse WHERE type_analyse = '$totest' AND filtering_possibility = 't';")}
		if ($res->{'type_analyse'} eq $totest) {return $res->{'type_analyse'}}
		else {&standard_error('12', $q)}
	}
	else {&standard_error('12', $q)}
}
# in ajax.pl, U2_subs2
sub get_genome_from_analysis {
	my ($analysis, $dbh) = @_;
	my $res =  $dbh->selectrow_hashref("SELECT manifest_name FROM valid_type_analyse WHERE type_analyse = '$analysis';");
	if ($res->{'manifest_name'} =~ /hg38/o) {return 'hg38'}
	else {return ''}
}

#used in add_analysis.pl, ajax.pl
sub check_filter {
	my ($q) = shift;
	if ($q->param('filter') =~ /^$ANALYSIS_MISEQ_FILTER$/) {return $1}
	else {&standard_error('20', $q)}
}
#used in import_illumina.pl
sub check_illumina_run_id {
	my ($q) = shift;
	if ($q->param('run_id') =~ /^(\d{6}_[A-Z]\d{5}_\d{4}_0{9}-[A-Z0-9]{5})$/o || $q->param('run_id') =~ /^(\d{6}_[A-Z]{2}\d{5,6}_\d{4}_[A-Z0-9]{10})$/o) {return $1}
	else {print $q->param('run_id').$q->br();&standard_error('21', $q)}
}
# used in ajax.pl
sub check_illumina_vcf_path {
	my ($q) = shift;
	if ($q->param('vcf_path') =~ /^$ABSOLUTE_HTDOCS_PATH$NAS_CHU_BASE_DIR\/([\w\/]+.vcf)$/) {return $1}
	# if ($q->param('vcf_path') =~ /^$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR\/data\/([\w\/]+.vcf)$/) {return $1}
	else {&standard_error('28', $q)}
}

sub check_class {
	my ($q, $dbh) = @_;
	my $query = "SELECT classe FROM valid_classe;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		if ($q->param('class') eq $result->{'classe'}) {
			return $result->{'classe'};
		}
	}
	&standard_error('17', $q)
}
sub check_acmg_class {
	my ($q, $dbh) = @_;
	my $query = "SELECT class FROM valid_acmg_class;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		if ($q->param('class') eq $result->{'class'}) {
			return $result->{'class'};
		}
	}
	&standard_error('17', $q)
}
sub check_rna_status {
	my ($q, $dbh) = @_;
	my $query = "SELECT type_arn FROM valid_type_arn;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		if ($q->param('rna_status') eq $result->{'type_arn'}) {
			return $result->{'type_arn'};
		}
	}
	&standard_error('24', $q)
}

# Error sub

sub standard_error { #returns an error and ends script
	my ($code, $q) = @_;
	my %error_code = (
		1	=>	'step numbering of the script',
		2	=>	'sample ID',
		3	=>	'patient phenotype',
		4	=>	'gene regexp',
		5	=>	'gene name',
		6	=>	'accession regexp',
		7	=>	'accession name',
		8	=>	'variant regexp',
		9	=>	'variant name',
		10	=>	'research character is not allowed',
		11	=>	'fact that the sample asked is unknown by the system',
		12	=>	'submitted analysis type',
		13	=>	'user credits (not an analyser)',
		14	=>	'fact that the submitted analysis already exists for this sample',
		15	=>	'segment information',
		16	=>	'unknown status',
		17	=>	'class error',
		18	=>	'fact that I cannot retrieve the patient ID in the MiSeq runs',
		19	=>	'manifest file name',
		20	=>	'filter name',
		21	=>	'run ID',
		22	=>	'transfer of the files from RS to U2',
		23	=>	'the mutalyzer webservice which is unreachable. Try again later',
		24	=>	'RNA status value',
		25	=>	'User name',
		26	=>	'Mutalyzer issue',
		27	=>	'Family ID',
		28	=>	'Illumina VCF path',
		29	=>	'proband'
	);
	print $q->start_p(), $q->span('USHVaM 2 encountered an error and cannot proceed further.'), $q->br(), $q->span("The error is linked to the $error_code{$code}."), $q->br(), $q->span('Please contact your admin.'), $q->end_p();
	&standard_end_html($q, $HTDOCS_PATH);
	print $q->end_html();
	exit();
}
# gene subs

sub get_gene_group {
	my ($gene, $dbh) = @_;
	my $query = "SELECT rp, dfn, usher FROM gene WHERE gene_symbol = '$gene';";
	my $res = $dbh->selectrow_hashref($query);
	return ($res->{'rp'}, $res->{'dfn'}, $res->{'usher'});
}

sub get_gene_from_nom_g {
	my ($q, $dbh) = @_;
	#if (uri_decode($q->param('nom_g')) =~ /(chr[\dXY]+:g\.[>\w\*\-\+\?_\{\}]+)/og) {
	if (uri_decode($q->param('nom_g')) =~ /(chr$CHR_REGEXP:$HGVS_CHR_TAG\.[>\w\*\-\+\?_\{\}]+)/og) {
		my $query = "SELECT refseq FROM variant WHERE nom_g = '$1';";
		my $res = $dbh->selectrow_hashref($query);
		if ($res->{'nom_gene'} ne '0E0') {return ($res->{'refseq'})}
		else {&standard_error('9', $q)}
	}
	else {&standard_error('8', $q)}
}

sub get_ng_accno {
	my ($gene, $acc, $dbh, $q) = @_;
	#gene, acc must have been checked before
	my $query = "SELECT acc_g FROM gene WHERE refseq = '$acc';";
	my $res = $dbh->selectrow_hashref($query);
	if ($res) {return $res->{'acc_g'}}
	else {&standard_error('5', $q)}
}

# Variants subs

sub color_by_classe {
	my ($classe, $dbh) = @_;
	my $query = "SELECT html_code FROM valid_classe WHERE classe = '$classe';";
	my $res = $dbh->selectrow_hashref($query);
	return $res->{'html_code'};
}
sub color_by_acmg_classe {
	my ($acmg_class, $dbh) = @_;
	if ($acmg_class ne '') {
		my $query = "SELECT html_code FROM valid_classe WHERE acmg_class = '$acmg_class';";
		my $res = $dbh->selectrow_hashref($query);
		return $res->{'html_code'};
	}
}
#in variant.pl
sub color_by_rna_status {
	my ($status, $dbh) = @_;
	my $query = "SELECT html_code FROM valid_type_arn WHERE type_arn = '$status';";
	my $res = $dbh->selectrow_hashref($query);
	return $res->{'html_code'};
}


#our $SIFT_THRESHOLD = 0.05;
#our $PPH2_THRESHOLD = 0.447;
#our $FATHMM_THRESHOLD = -1.5;
#our $METALR_THRESHOLD = 0.5;
#our $MCAP_THRESHOLD = 0.025;

###subs for SIFT and co querying with SQLlite or VEP or dbNSFP
sub sift_color {
	my $score = shift;
	if ($score ne '.') {
		if ($score < $SIFT_THRESHOLD) {return '#FF0000'}
		else {return '#00A020'}
	}
	else {return '#000000'}
}

sub sift_interpretation {
	my $score = shift;
	if ($score < $SIFT_THRESHOLD) {return 'damaging'}
	else {return 'tolerated'}
}

sub sift_color2 {
	my $res = shift;
	if ($res =~ /deleterious/) {return '#FF0000'}
	else {return '#00A020'}
}

sub pph2_color {
	my $res = shift;
	if ($res =~ /damaging/) {return '#FF0000'}
	else {return '#00A020'}
}

sub pph2_color2 {
	my $score = shift;
	if ($score ne '.') {
		if ($score > $PPH2_THRESHOLD) {return '#FF0000'}
		else {return '#00A020'}
	}
	else {return '#000000'}
}

sub fathmm_color {
	my $score = shift;
	if ($score ne '.') {
		if ($score < $FATHMM_THRESHOLD) {return '#FF0000'}
		else {return '#00A020'}
	}
	else {return '#000000'}
}

sub metalr_color {
	my $score = shift;
	if ($score ne '.') {
		if ($score > $METALR_THRESHOLD) {return '#FF0000'}
		else {return '#00A020'}
	}
	else {return '#000000'}
}

sub mcap_color {
	my $score = shift;
	if ($score > $MCAP_THRESHOLD) {return '#FF0000'}
	else {return '#00A020'}
}

sub spliceAI_color {
	my $score = shift;
	if ($score > $SPLICEAI_THRESHOLD_MAX) {return '#FF0000'}
	elsif ($score > $SPLICEAI_THRESHOLD_MED) {return '#FF6020'}
	elsif ($score > $SPLICEAI_THRESHOLD_MIN) {return '#FFA020'}
	else {return '#00A020'}
}

#in engine.pl, U2_subs_2 (RNA_pie), ajax.pl
sub get_interpreted_position {
	my ($result, $dbh) = @_;
	if ($result->{'type_segment'} eq 'exon') {
		my ($dist, $label) = U2_modules::U2_subs_1::get_pos_from_intron($result, $dbh);
		if ($dist <= 3 && $dist >= 0) {return "exonic near $label"}
		elsif ($label eq 'overlap') {return 'overlap junction'}
		else {return 'exonic middle'}
	}
	elsif ($result->{'type_segment'} eq 'intron') {
		my $dist = U2_modules::U2_subs_1::get_pos_from_exon($result->{'nom'});
		if ($dist < 3 && $dist > 0) {return 'cannonical site'}
		elsif ($dist > 100) {return 'deep intronic'}
		elsif ($dist != -1) {return 'other intronic'}
		elsif ($dist == -1) {return 'overlap junction'}
	}
}

#in variant.pl, patient_genotype.pl, engine.pl, ajax.pl, automated_class.pl
sub extract_pos_from_genomic { #get chr and genomic positions
	my ($genomic, $type) = @_;
	#if ($genomic =~ /^chr([\dXY]+):g\.(\d+)[\+-]?\??_?(\d*)[^\d]*/o) {
	#print $genomic;
	if ($genomic =~ /^chr($CHR_REGEXP):$HGVS_CHR_TAG\.(\d+)[\+-]?\??_?(\d*)[^\d]*/) {
		#print "--$type--$3--";
		if ($type eq 'clinvar') {return ($1, $2)}
		elsif ($type eq 'evs') {
			if ($3 ne '') {return ($1, $2, $3)}
			else {return ($1, $2, $2)}
		}
	}
}

sub extract_dvd_var {#get genomic variant without chr prefix
	my $genomic = shift;
	if ($genomic =~ /^chr($CHR_REGEXP:)$HGVS_CHR_TAG\.(\d+[\+-]?\??_?\d*)([^\d]*)/) {return "$1$2:$3"}
}

sub extract_chrpos_var {#get genomic position and chr w/o prefix formatted for DVD + extended boundaries
	my $genomic = shift;
	if ($genomic =~ /^chr($CHR_REGEXP:)$HGVS_CHR_TAG\.(\d+[\+-]?\??_?\d*)[^\d]*/) {
		my ($chr, $pos) = ($1, $2);
		if ($pos =~ /(.+)_(.+)/o) {
			return $chr.($1-4)."-".($2+4)
		}
		else {return $chr.($pos-4)."-".($pos+4)}
		#return "$1$2"
	}
}

#in gene_graphs.pl, variant.pl, engine.pl, ajax.pl
sub get_pos_from_exon {
	my $name = shift;
	if ($name !~ /_/ && $name =~ /$HGVS_TRANSCRIPT_TAG\.-?\d+[\+-](\d+)[^_]/) {return $1}
	elsif ($name =~ /$HGVS_TRANSCRIPT_TAG\.-?\d+([\+-])(\d+)_\d+[\+-](\d+)[^\d]/) {
		if ($1 eq '+') {return $2}
		elsif ($1 eq '-') {return $3}
	}
	else {return -1}#overlap
}
#in gene_graphs.pl, variant.pl, engine.pl, ajax.pl
sub get_pos_from_intron {
	my ($result, $dbh) = @_;
	my ($nom_g, $gene, $acc, $num_seg, $type_seg, $num_seg_end, $type_seg_end) = ($result->{'nom_g'}, $result->{'gene_symbol'}, $result->{'refseq'}, $result->{'num_segment'}, $result->{'type_segment'}, $result->{'num_segment_end'}, $result->{'type_segment_end'});
	#1st extract position(s)
	my ($chr, $pos1, $pos2) = &extract_pos_from_genomic($nom_g, 'evs');
	#2nd get strand
	my $query = "SELECT brin FROM gene WHERE refseq = '$acc';";
	my $res = $dbh->selectrow_hashref($query);
	#possible overlapping?

	if ($pos1 == $pos2) {
		#NO - simple case
		return &compute_exonic_positions("SELECT $postgre_start_g, $postgre_end_g, taille FROM segment WHERE refseq = '$acc' AND type = '$type_seg' AND numero = '$num_seg';", $pos1, $res->{'brin'}, $dbh);
	}
	else {
		if ($type_seg ne $type_seg_end) { #overlap
			return ('-1', 'overlap')
		}
		else {#only exonic
			my ($dist5, $label5) = &compute_exonic_positions("SELECT $postgre_start_g, $postgre_end_g, taille FROM segment WHERE refseq = '$acc' AND type = '$type_seg' AND numero = '$num_seg';", $pos1, $res->{'brin'}, $dbh);
			my ($dist3, $label3) = &compute_exonic_positions("SELECT $postgre_start_g, $postgre_end_g, taille FROM segment WHERE refseq = '$acc' AND type = '$type_seg_end' AND numero = '$num_seg_end';", $pos2, $res->{'brin'}, $dbh);
			if ($dist5 > $dist3) {return ($dist3, $label3)}
			elsif ($dist5 < $dist3) {return ($dist5, $label5)}
			elsif ($dist5 == $dist3) {return ($dist5, 'middle')}
		}
	}
}
#same
sub compute_exonic_positions {
	my ($query, $pos, $strand, $dbh) = @_;
	my $res = $dbh->selectrow_hashref($query);
	my ($dist1, $dist2);
	if ($strand eq '+') {($dist1, $dist2) = (($pos - ($res->{$postgre_start_g}-1)), (($res->{$postgre_end_g}+1) - $pos))}#intronic exact 1st nts
	elsif ($strand eq '-') {($dist1, $dist2) = ((($res->{$postgre_start_g}+1) - $pos), ($pos - ($res->{$postgre_end_g}-1)))}
	if ($dist1 <= $res->{'taille'} && $dist2 <= $res->{'taille'}) {
		if ($dist1 > $dist2) {
			#if ($strand eq '+') {return ($dist2, 'donor')}
			#elsif ($strand eq '-') {return ($dist2, 'acceptor')}
			return ($dist2, 'donor')
		}
		elsif ($dist1 < $dist2) {
			#if ($strand eq '+') {return ($dist1, 'acceptor')}
			#if ($strand eq '-') {return ($dist1, 'donor')}
			return ($dist1, 'acceptor')
		}
		else {return ($dist1, 'middle')}
	}
	else {print "size pb with $query-$pos-$dist1-$dist2-$res->{'taille'}::"}
}

#in variant.pl & variant creation scripts
sub get_deleted_sequence {
	my $mutalyzer_seq = shift;
	if ($mutalyzer_seq =~ /[ATCG]\s([ATGC]+)\s[ATGC]/) {
		return $1
	}
}

sub getExacFromGenoVar {
	my $genomic = shift;
	#if ($genomic =~ /chr([0-9XY]{1,2}):g.(\d+)([ATCG])>([ATGC])/o) {
	if ($genomic =~ /chr($CHR_REGEXP):$HGVS_CHR_TAG.(\d+)([ATCG])>([ATGC])/o) {
		return "$1-$2-$3-$4"
	}
}

sub get_chr_from_gene {
	my ($gene, $dbh) = @_;
	my $query = "SELECT chr FROM gene where gene_symbol = '$gene';";
	my $res = $dbh->selectrow_hashref($query);
	return $res->{'chr'};
}

sub is_large {
	my ($var) = shift;
	if ($var->{'taille'} > 50) {return 1}
	return 0
}

sub is_pathogenic {
	my $var = shift;
	if ($var->{'classe'} eq 'VUCS class III' || $var->{'classe'} eq 'VUCS class IV' || $var->{'classe'} eq 'pathogenic' || $var->{'classe'} eq 'ACMG class IV' || $var->{'classe'} eq 'ACMG class V') {return 1}
	return 0
}

sub is_class_pathogenic {
	my $class = shift;
	if ($class eq 'VUCS class III' || $class eq 'VUCS class IV' || $class eq 'pathogenic' || $class eq 'ACMG class IV' || $class eq 'ACMG class V') {return 1}
	return 0
}

#in splicing_calc.pl
sub get_last_exon_number {
	my ($transcript, $dbh) = @_;
	my $query = "SELECT numero-1 as a FROM segment WHERE refseq = '$transcript' AND type = '3UTR';";
	my $res = $dbh->selectrow_hashref($query);
	#print "--$res->{'a'}--";
	return $res->{'a'};
}

sub maf {
	my ($dbh, $gene, $acc, $var, $analyse) = @_;
	my $maf = 'NA';
	my $query = "SELECT COUNT(DISTINCT(num_pat)) as a FROM variant2patient a, patient b WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND a.type_analyse ~ '$analyse' AND a.refseq = '$acc' AND a.nom_c = '$var' AND a.statut <> 'homozygous' AND b.proband = 't';";
	my $res_1 = $dbh->selectrow_hashref($query);
	$query = "SELECT COUNT(DISTINCT(num_pat)) as a FROM variant2patient a, patient b WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND a.type_analyse ~ '$analyse' AND a.refseq = '$acc' AND a.nom_c = '$var' AND a.statut = 'homozygous' AND b.proband = 't';";
	my $res_2 = $dbh->selectrow_hashref($query);
	my $alleles = $res_1->{'a'} + ($res_2->{'a'} * 2);
	$query = "SELECT COUNT(DISTINCT(num_pat)) as a FROM analyse_moleculaire a, patient b WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND a.type_analyse ~ '$analyse' AND a.refseq = '$acc' AND b.proband = 't';";
	my $res_3 = $dbh->selectrow_hashref($query);
	my $total = $res_3->{'a'} * 2;
	if ($total == 0) {$maf = 'NA';return $maf;}
	$maf = sprintf('%.3f', ($alleles/$total));
	if ($maf == 0) {$maf = 'NA'}
	return $maf;
}


sub one2three {
    my ($aa) = shift;
    my  %amino_acid = (
	    'A' => 'Ala',
	    'C' => 'Cys',
	    'D' => 'Asp',
	    'E' => 'Glu',
	    'F' => 'Phe',
	    'G' => 'Gly',
	    'H' => 'His',
	    'I' => 'Ile',
	    'K' => 'Lys',
	    'L' => 'Leu',
	    'M' => 'Met',
	    'N' => 'Asn',
	    'P' => 'Pro',
	    'Q' => 'Gln',
	    'R' => 'Arg',
	    'S' => 'Ser',
	    'T' => 'Thr',
	    'V' => 'Val',
	    'W' => 'Trp',
	    'Y' => 'Tyr',
			'*' => 'Ter'
    );
    return $amino_acid{$aa};
}

sub three2one {
    my ($aa) = shift;
    my  %amino_acid = (
	    'Ala' => 'A',
	    'Cys' => 'C',
	    'Asp' => 'D',
	    'Glu' => 'E',
	    'Phe' => 'F',
	    'Gly' => 'G',
	    'His' => 'H',
	    'Ile' => 'I',
	    'Lys' => 'K',
	    'Leu' => 'L',
	    'Met' => 'M',
	    'Asn' => 'N',
	    'Pro' => 'P',
	    'Gln' => 'Q',
	    'Arg' => 'R',
	    'Ser' => 'S',
	    'Thr' => 'T',
	    'Val' => 'V',
	    'Trp' => 'W',
	    'Tyr' => 'Y',
	    'del' => 'del',
			'dup' => 'dup',
			'Ter' => '*'
    );
    return $amino_acid{$aa};
}

sub nom_three2one{
	my $var = shift;
	$var =~ s/\(//og;
	$var =~ s/\)//og;
	if ($var =~ /^p\.(\w{3})(\d+)(\w{3})$/o) {return &three2one($1).$2.&three2one($3)}
	elsif ($var =~ /^p\.(\w{3})(\d+_)(\w{3})(\d+.+)$/o) {return &three2one($1).$2.&three2one($3).$4}
}

sub get_strand {
	my ($gene, $dbh) = @_;
	my $res = $dbh->selectrow_hashref("SELECT brin FROM gene WHERE gene_symbol = '$gene' AND main = 't';");
	my $order = 'ASC';
	if ($res->{'brin'} eq '-') {$order = 'DESC'}
	return $order;
}

sub get_nom_segment_main {
	my ($num, $gene, $dbh) = @_;
	my $query = "SELECT a.nom FROM segment a, gene b WHERE a.refseq = b.refseq AND b.gene_symbol = '$gene' AND b.main = 't' AND a.numero = '$num' AND a.type <> 'intron';";
	my $res = $dbh->selectrow_hashref($query);
	return $res->{'nom'};
}

sub test_mutalyzer {
	my $ua = LWP::UserAgent->new();
	#http://mutalyzer.nl/2.0/services
	#####remove when certificate ok at mutalyzer.nl!!!!!
	#$ua->ssl_opts(verify_hostname => 0);
	my $request = $ua->get('https://v2.mutalyzer.nl/services');
	my $content = $request->content();
	# print "$content<br/>";
	if ($content !~ /soap/o) {return 0}
	else {return 1}
}

sub run_mutalyzer {
	my ($soap, $acc_g, $gene, $var, $mutalyzer_version, $mutalyzer_acc) = @_;
	if ($mutalyzer_acc && $mutalyzer_acc ne '') {$acc_g = $mutalyzer_acc}
	#if ($mutalyzer_acc && $mutalyzer_acc ne '') {$acc_g = $mutalyzer_acc}
	#print "$acc_g($gene$mutalyzer_version:$var";
	#GPR98/ADGRV1 exception
	# if ($gene eq 'GPR98') {$gene = 'ADGRV1'}
	my $call = $soap->call('runMutalyzer', SOAP::Data->name('variant')->value("$acc_g($gene$mutalyzer_version):$var"));
	if ($call->fault()) {print "Mutalyzer Fault $var $gene<br/>"}
	return $call;
}
#variant_input_vv.pl
sub test_vv {
	my $ua = shift;
	#my $ua = LWP::UserAgent->new();
	#$ua->ssl_opts(verify_hostname => 0);
	#$ua->proxy('https', 'http://194.167.35.151:3128/');

	my $request = $ua->get("$VARIANTVALIDATOR_GENUINE_API/hello/?content-type=application/json");
	if ($request->is_success() && exists(decode_json($request->content())->{'status'}) && decode_json($request->content())->{'status'} eq 'hello_world') {
			return "$VARIANTVALIDATOR_GENUINE_API/VariantValidator/variantvalidator";
	}
	else {
		$request = $ua->get("$VARIANTVALIDATOR_EMERGENCY_API/hello/?content-type=application/json");
		if ($request->is_success() && exists(decode_json($request->content())->{'status'}) && decode_json($request->content())->{'status'} eq 'hello_world') {
			print STDERR "\nSwitching to emergency VV REST API\n";
				return "$VARIANTVALIDATOR_EMERGENCY_API/VariantValidator/variantvalidator";
		}
	}
	return 'no VV available'
}
#variant_input_vv.pl, import_illumina_vv.pl
sub run_vv {
	my ($genome, $nm, $var, $mode) = @_;
	my $ua = LWP::UserAgent->new();

	my $vv_api_url = &test_vv($ua);

	if ($vv_api_url ne 'no VV available') {
		#$ua->ssl_opts(verify_hostname => 0);
		#$ua->proxy('https', 'http://194.167.35.151:3128/');
		my $url = "$vv_api_url/$genome/$nm:$var/$nm?content-type=application/json";
		if ($mode eq 'VCF') {
			$url = "$vv_api_url/$genome/$var/$nm?content-type=application/json";
		}
		# print STDERR "$url\n";
		my $request = $ua->get($url);
		# print STDERR "asked URL: $url\n";
		# print STDERR '$request->decoded_content():'.Dumper($request->decoded_content())."\n";
		if ($request->is_success()) {return $request->decoded_content()}
		else {return '0'}
	}
	else {
		my $error = {'url_error' => 'VV down'};
		return encode_json($error);
	}
}


#U2_subs_3, variant_input.pl
sub test_myvariant {
	my $ua = LWP::UserAgent->new();
	my $request = $ua->get('http://myvariant.info');
	if ($request->is_success()) {return 1}
	else {return 0}
}
sub test_mygene {
	my $ua = LWP::UserAgent->new();
	my $request = $ua->get('http://mygene.info');
	if ($request->is_success()) {return 1}
	else {return 0}
}
#U2_subs_3, variant_input.pl
sub run_myvariant {
	my ($var, $fields, $email) = @_;
	if ($email && $email ne '') {$email = "&email=$email"}
	else {$email = ''}
	my $ua = LWP::UserAgent->new();
	if ($var =~ /(^chr.+[delup]{3})[ATGC]+$/o) {$var = $1}
	my $request = $ua->get(uri_encode("http://myvariant.info/v1/variant/$var?fields=$fields$email"));
	if ($request->is_success()) {
		return decode_json($request->content());
	}
	#return decode_json($ua->get(uri_encode("http://myvariant.info/v1/variant/$var?fields=$fields&email=".$email)));
}
sub run_mygene {
	my ($gene, $fields, $email) = @_;
	#if ($email && $email ne '') {$email = "&email=$email"}
	#else {$email = ''}
	my $ua = LWP::UserAgent->new();
	my $request = $ua->get(uri_encode("http://mygene.info/v3/query?q=$gene&fields=$fields"));
	#print "http://mygene.info/v3/query?q=$gene?fields=$fields";
	if ($request->is_success()) {
		return decode_json($request->content());
	}
	#return decode_json($ua->get(uri_encode("http://myvariant.info/v1/variant/$var?fields=$fields&email=".$email)));
}

sub test_ncbi {
	my $ua = LWP::UserAgent->new();
	my $request = $ua->get('https://www.ncbi.nlm.nih.gov/');
	if ($request->is_success()) {return 1}
	else {print STDERR $request->content(); return 0}
}
sub run_litvar {
	my $snp_id = shift;

	# on 158 Xserve, perl was unable to contact litavr because of SSL version -> use of a python script instead - revert back to pure perl implementation 20210302
	# my $url = "https://www.ncbi.nlm.nih.gov/research/bionlp/litvar/api/v1/public/rsids2pmids?rsids=$snp_id";
	# return decode_json(`$PYTHON $ABSOLUTE_HTDOCS_PATH/litvar.py "$url"`) or die $!;
	#print STDERR "--$litvar_result->[0]{'pmids'}\n";

	my $ua = LWP::UserAgent->new();
	##my $request = $ua->get("https://www.ncbi.nlm.nih.gov/research/bionlp/litvar/api/v1/public/pmids?query=%7B%22variant%22%3A%5B%22litvar%40$snp_id%23%23%22%5D%7D");
	my $request = $ua->get("https://www.ncbi.nlm.nih.gov/research/bionlp/litvar/api/v1/public/rsids2pmids?rsids=$snp_id");
	##print "http://mygene.info/v3/query?q=$gene?fields=$fields";
	if ($request->is_success()) {
		return decode_json($request->content());
	#	#return $request->content();
	}
	else {return "litvar error: $request->status_line()"}
}

#ajax.pl
#sub run_myvariantMafs {
#	my ($var, $email) = @_;
#	my $ua = LWP::UserAgent->new();
#	my $request = $ua->get(uri_encode("http://myvariant.info/v1/variant/$var?fields=gnomad_exome.af,gnomad_genome.af,cadd.esp.af,dbnsfp.1000gp3.af&email=".$email));
#	if ($request->is_success()) {
#		return decode_json($request->content());
#	}
#}


# Other

sub get_date { # returns a date in a specific format
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	my $month = ($mon+1);
	if ($month < 10) {$month = "0$month"}
	if ($mday < 10) {$mday = "0$mday"}
	return (1900+$year)."-$month-".$mday;
}

sub get_log_date {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	my $month = ($mon+1);
	if ($month < 10) {$month = "0$month"}
	if ($mday < 10) {$mday = "0$mday"}
	if ($hour < 10) {$hour = "0$hour"}
	if ($min < 10) {$min = "0$min"}
	if ($sec < 10) {$sec = "0$sec"}
	return "[".(1900+$year)."/$month/$mday $hour:$min:$sec]";
}

sub get_run_date {#get date from illumina run_id (pg format)
	my $id = shift;
	$id =~ /^(\d{2})(\d{2})(\d{2})_/o;
	return "20$1-$2-$3";
}

sub date_pg2tjs { #transform date in pg format to timeline format
	my $date = shift;
	$date =~ s/-/,/og;
	return $date;
}

sub translate_boolean {
	my ($boolean) = shift;
	#print "__".$boolean."__";
	#print length($boolean);
	if (defined($boolean) && $boolean == 1) {return '+'}
	elsif(defined($boolean)) {return '-'}
	else {return 'UNDEFINED'}
}

sub translate_boolean_class {
	my ($boolean) = shift;
	if (defined($boolean) && $boolean == 1) {return 'yes'}
	elsif(defined($boolean)) {return 'no'}
	else {return 'undefined'}
}

sub translate_boolean_denovo {
	my ($boolean) = shift;
	if (defined($boolean) && $boolean ne "" && $boolean == 1) {return ' denovo'}
	else {return ''}
}

sub translate_valide_human {
	my ($boolean) = shift;
	if (defined($boolean) && $boolean == 1) {return 'Validated'}
}

sub translate_result_human {
	my ($boolean) = shift;
	if (defined($boolean) && $boolean == 1) {return 'Positive'}
	elsif(defined($boolean)) {return 'Negative'}
	else {return 'Undefined'}
}

#used in add_analysis.pl, import_illumina.pl

sub nas_connexion {
	my ($link, $q) = @_;
	my $SSH_RACKSTATION_LOGIN = $config->SSH_RACKSTATION_LOGIN();
	my $SSH_RACKSTATION_PASSWORD = $config->SSH_RACKSTATION_PASSWORD();
	my $SSH_RACKSTATION_IP = $config->SSH_RACKSTATION_IP();
	#initiate connexion to RackStation where the data actually is
	#we first need to set up the connexion, a little bit difficult under mod_perl as
	#STDIN and STDOUT are not related to real file handles under mod_perl so we need to fix it
	#and Net::OpenSSH requires a secure ctl_dir
	#also needs ~/.ssh (see google .ssh apache) with a proper public key in the known_hosts file
	#need to untaint /dev/null - not sure of the method but it works
	$ENV{PATH} = '/dev/null';
	open my $def, '<', '/dev/null' or die "unable to open /dev/null";
	my $ctl_dir = tempdir(CLEANUP => 1, TMPDIR => 1) or die $!;
	my $ssh = Net::OpenSSH->new("$SSH_RACKSTATION_LOGIN:$SSH_RACKSTATION_PASSWORD\@$SSH_RACKSTATION_IP", default_stdin_fh => $def, default_stdout_fh => $def, ctl_dir => $ctl_dir);
	$ssh->error() and die "$link Can't ssh to RackStation: " . $ssh->error() . $q->br() . "If you see this page, please contact your admin and keep the error message.";
	return $ssh;
}

# in ajax.pl
sub seal_connexion {
	my ($link, $ssh_ip, $q) = @_;
	# my $SEAL_IP = $config->SEAL_IP();
	my $SEAL_USER = $config->SEAL_USER();
	my $SEAL_PASSWORD = $config->SEAL_PASSWORD();
	# print STDERR "$SEAL_USER:$SEAL_PASSWORD\@$SEAL_IP\n";
	#initiate connexion to RackStation where the data actually is
	#we first need to set up the connexion, a little bit difficult under mod_perl as
	#STDIN and STDOUT are not related to real file handles under mod_perl so we need to fix it
	#and Net::OpenSSH requires a secure ctl_dir
	#also needs ~/.ssh (see google .ssh apache) with a proper public key in the known_hosts file
	#need to untaint /dev/null - not sure of the method but it works
	# $ENV{PATH} = '/dev/null';
	open my $def, '<', '/dev/null' or die "unable to open /dev/null";
	my $ctl_dir = tempdir(CLEANUP => 1, TMPDIR => 1) or die $!;
	my $ssh = Net::OpenSSH->new("$SEAL_USER:$SEAL_PASSWORD\@$ssh_ip", default_stdin_fh => $def,default_stdout_fh => $def, ctl_dir => $ctl_dir);
	$ssh->error() and die "$link Can't ssh to SEAL: " . $ssh->error() . $q->br() . "If you see this page, please contact youradmin and keep the error message.";
	return $ssh;
}


1;
